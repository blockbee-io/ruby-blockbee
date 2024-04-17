# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module BlockBee
  class Error < StandardError; end

  VERSION = "1.0.0"

  BLOCKBEE_URL = 'https://api.blockbee.io/'
  BLOCKBEE_HOST = 'api.blockbee.io'

  class API
    def initialize(coin, own_address = '', callback_url, parameters, bb_params, api_key)
      raise 'API Key Missing' if api_key.nil?

      raise 'Callback URL Missing' if callback_url.nil?

      @callback_url = callback_url
      @coin = coin
      @own_address = own_address
      @parameters = parameters || {}
      @bb_params = bb_params || {}
      @api_key = api_key
      @payment_address = ''

      if parameters
        _cb = URI::parse(callback_url)

        @callback_url = URI::HTTPS.build(
          host: _cb.host,
          path: _cb.path,
          query: URI.encode_www_form(parameters)
        )
      end
    end

    def get_address
      return nil if @coin.nil?

      _params = {
        'callback' => @callback_url,
        'apikey' => @api_key
      }.merge(@bb_params)

      if !@own_address.nil? && !@own_address.empty?
       (_params['address'] = @own_address)
      end

      _address = BlockBee::process_request_get(@coin, 'create', _params)

      return nil unless _address

      @payment_address = _address['address_in']

      _address
    end

    def get_logs
      _params = {
        'callback' => @callback_url,
        'apikey' => @api_key
      }

      _logs = BlockBee::process_request_get(@coin, 'logs', _params)

      return nil unless _logs

      p _logs

      _logs
    end

    def get_qrcode(value = '', size = 300)
      return nil if @coin.nil?

      address = @payment_address

      address = get_address['address_in'] if address.empty?

      _params = {
        'address' => address,
        'size' => size,
        'apikey' => @api_key
      }

      _params['value'] = value unless value.empty?

      _qrcode = BlockBee::process_request_get(@coin, 'qrcode', _params)

      return nil unless _qrcode

      _qrcode
    end

    def get_conversion(from_coin, value)
      _params = {
        'from' => from_coin,
        'value' => value,
        'apikey' => @api_key
      }

      _conversion = BlockBee::process_request_get(@coin, 'convert', _params)

      return nil unless _conversion

      _conversion
    end

    def self.get_info(coin, api_key, prices = 0)
      raise 'API Key Missing' if api_key.nil?

      _params = {
        'prices' => prices,
        'apikey' => api_key
      }

      _info = BlockBee::process_request_get(coin, 'info', _params)

      return nil unless _info

      _info
    end

    def self.get_supported_coins(api_key)
      raise 'API Key Missing' if api_key.nil?

      _info = get_info(nil, api_key )

      _info.delete('fee_tiers')

      _coins = {}

      _info.each do |ticker, coin_info|
        if coin_info.key?('coin')
          _coins[ticker] = coin_info['coin']
        else
          coin_info.each do |token, token_info|
            _coins[ticker + '_' + token] = token_info['coin'] + ' (' + ticker.upcase + ')'
          end
        end
      end

      _coins
    end

    def self.get_estimate(coin, addresses = 1, priority = 'default', api_key)
      raise 'API Key Missing' if api_key.nil?

      params = {
        'addresses' => addresses,
        'priority' => priority,
        'apikey' => api_key
      }

      _estimate = BlockBee::process_request_get(coin, 'estimate', params)

      return nil unless _estimate

      _estimate
    end

    def self.create_payout(coin, payout_requests, api_key, process = false)
      raise 'No requests provided' if payout_requests.nil? || payout_requests.empty?

      body = { 'outputs' => payout_requests }

      endpoint = 'payout/request/bulk'

      endpoint += '/process' if process

      _payout = BlockBee::process_request_post(coin, endpoint, api_key, body, true)

      return nil unless _payout['status'] == 'success'

      _payout
    end

    def self.list_payouts(coin, status: 'all', page: 1, api_key:, payout_request: false)
      return nil if api_key.nil?

      _params = {
        'apikey' => api_key,
        'status' => status,
        'page' => page
      }

      endpoint = 'payout/list'

      endpoint = 'payout/request/list' if payout_request

      _payouts = BlockBee::process_request_get(coin, endpoint, _params)

      return nil unless _payouts['status'] == 'success'

      _payouts
    end

    def self.get_payout_wallet(coin, api_key, balance = false)
      wallet = BlockBee::process_request_get(coin, 'payout/address', 'apikey' => api_key)

      return nil unless wallet['status'] == 'success'

      output = { 'address' => wallet['address'] }

      if balance
        wallet_balance = BlockBee::process_request_get(coin, 'payout/balance', 'apikey' => api_key)

        if wallet_balance['status'] == 'success'
          output['balance'] = wallet_balance['balance']
        end
      end

      output
    end

    def self.create_payout_by_ids(api_key, payout_ids)
      raise 'Please provide the Payout Request(s) ID(s)' if payout_ids.nil? || payout_ids.empty?

      _payout = BlockBee::process_request_post(nil, 'payout/create', api_key, { 'request_ids' => payout_ids.join(',') })

      return nil unless _payout['status'] == 'success'

      _payout
    end

    def self.process_payout(api_key, payout_id)
      return nil if payout_id.nil?

      _process = BlockBee::process_request_post(nil, 'payout/process', api_key, { 'payout_id' => payout_id })

      return nil unless _process['status'] == 'success'

      _process
    end

    def self.check_payout_status(api_key, payout_id)
      raise 'Please provide the Payout ID' if payout_id.nil? or (payout_id.is_a? String and payout_id.empty?)

      _status = BlockBee::process_request_post(nil, 'payout/status', api_key, { 'payout_id' => payout_id })

      return nil unless _status['status'] == 'success'

      _status
    end
  end

  class Checkout
    def initialize(parameters: {}, bb_params: {}, notify_url:, api_key:)
      raise 'API Key Missing' if api_key.nil?

      @parameters = parameters
      @bb_params = bb_params
      @api_key = api_key
      @notify_url = notify_url

      if @parameters
        _nu = URI::parse(notify_url)

        @notify_url = URI::HTTPS.build(
          host: _nu.host,
          path: _nu.path,
          query: URI.encode_www_form(parameters)
        )
      end
    end

    def payment_request(redirect_url, value)
      raise 'Please provide a redirect url' if redirect_url.nil? or redirect_url.empty?

      raise 'Value must be a integer' unless value.is_a?(Integer)

      _params = {
        'redirect_url' => redirect_url,
        'notify_url' => @notify_url,
        'value' => value,
        'apikey' => @api_key
      }.merge(@bb_params)

      _request = BlockBee::process_request_get(nil, 'checkout/request', _params)

      return nil unless _request['status'] == 'success'

      _request
    end

    def self.payment_logs(token, api_key)
      raise 'API Key required' if api_key.nil? or api_key.empty?

      raise 'Token required' if token.nil? or token.empty?

      _params = {
        'apikey' => api_key,
        'token' => token
      }

      _logs = BlockBee::process_request_get(nil, 'checkout/logs', _params)

      return nil unless _logs['status'] == 'success'

      _logs
    end

    def deposit_request()
      _params = {
        'notify_url' => @notify_url,
        'apikey' => @api_key
      }.merge(@bb_params)

      _request = BlockBee::process_request_get(nil, 'deposit/request', _params)

      return nil unless _request['status'] == 'success'

      _request
    end

    def self.deposit_logs(token, api_key)
      raise 'API Key required' if api_key.nil? or api_key.empty?

      raise 'Token required' if token.nil? or token.empty?

      _params = {
        'apikey' => api_key,
        'token' => token
      }

      _logs = BlockBee::process_request_get(nil, 'deposit/logs', _params)

      return nil unless _logs['status'] == 'success'

      _logs
    end
  end

  private

  def self.process_request_get(coin = '', endpoint = '', params = nil)
    coin = coin.nil? ? '' : "#{coin.tr('_', '/')}/"

    response = Net::HTTP.get(URI.parse("#{BLOCKBEE_URL}#{coin}#{endpoint}/?#{URI.encode_www_form(params)}"))

    JSON.parse(response)
  end

  def self.process_request_post(coin = '', endpoint = '', api_key = '', body = nil, is_json = false)
    coin_path = coin.nil? ? '' : "#{coin.tr('_', '/')}/"

    p coin_path

    url = "#{BLOCKBEE_URL}#{coin_path}#{endpoint}/?apikey=#{api_key}"
    uri = URI.parse(url)

    p url

    req = Net::HTTP::Post.new(uri)
    req['Host'] = BLOCKBEE_HOST

    if is_json
      req.content_type = 'application/json'
      req.body = body.to_json
    else
      req.set_form_data(body)
    end

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

    JSON.parse(res.body)
  end
end
