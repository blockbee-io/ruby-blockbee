# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module BlockBee
  class APIError < StandardError
    attr_reader :status_code

    def initialize(message, status_code)
      super(message)
      @status_code = status_code
    end

    def self.from_status_code(status_code, message)
      case status_code
      when 400
        new("Bad Request: #{message}", 400)
      when 401
        new("Unauthorized: #{message}", 401)
      when 403
        new("Forbidden: #{message}", 403)
      when 404
        new("Not Found: #{message}", 404)
      when 500
        new("Internal Server Error", 500)
      else
        new("Unexpected Error: #{message}", status_code)
      end
    end
  end

  class MissingAPIKeyError < StandardError; end

  class CallbackURLMissing < StandardError; end

  VERSION = "1.0.1"

  BLOCKBEE_URL = 'https://api.blockbee.io/'
  BLOCKBEE_HOST = 'api.blockbee.io'

  class API
    def initialize(coin, callback_url, api_key, own_address: '', parameters: {}, bb_params: {})
      raise BlockBee::MissingAPIKeyError, 'Provide your API Key' if api_key.nil?
      raise BlockBee::CallbackURLMissing, 'Provide your callback URL' if callback_url.nil?

      _cb = URI::parse(callback_url)

      @callback_url = URI::HTTPS.build(
        host: _cb.host,
        path: _cb.path,
        query: URI.encode_www_form(parameters)
      )

      @coin = coin
      @own_address = own_address
      @parameters = parameters
      @bb_params = bb_params
      @api_key = api_key
      @payment_address = ''
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

      _address = BlockBee::process_request_get(@coin, 'create', params: _params)

      @payment_address = _address['address_in']

      _address
    end

    def get_logs
      _params = {
        'callback' => @callback_url,
        'apikey' => @api_key
      }

      _logs = BlockBee::process_request_get(@coin, 'logs', params: _params)

      _logs
    end

    def get_qrcode(value: nil, size: 300)
      return nil if @coin.nil?

      address = @payment_address

      address = get_address['address_in'] if address.empty?

      _params = {
        'address' => address,
        'size' => size
      }

      if value.is_a? Numeric
        _params['value'] = value
      end

      _qrcode = BlockBee::process_request_get(@coin, 'qrcode', params: _params)

      _qrcode
    end

    def get_conversion(from_coin, value)
      _params = {
        'from' => from_coin,
        'value' => value,
      }

      _conversion = BlockBee::process_request_get(@coin, 'convert', params: _params)

      _conversion
    end

    def self.get_info(coin, prices: 0)
      _params = {
        'prices' => prices,
      }

      _info = BlockBee::process_request_get(coin, 'info', params: _params)
    end

    def self.get_supported_coins()
      _info = get_info(nil)

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

    def self.get_estimate(coin, api_key, addresses: 1, priority: 'default')
      raise BlockBee::MissingAPIKeyError, 'Provide your API Key' if api_key.nil?

      _params = {
        'addresses' => addresses,
        'priority' => priority,
      }

      _estimate = BlockBee::process_request_get(coin, 'estimate', params: _params)

      _estimate
    end

    def self.create_payout(coin, payout_requests, api_key, process: false)
      body = { 'outputs' => payout_requests }

      endpoint = 'payout/request/bulk'

      endpoint += '/process' if process

      _payout = BlockBee::process_request_post(coin, endpoint, api_key, body: body, is_json: true)

      _payout
    end

    def self.list_payouts(coin, api_key, status: 'all', page: 1, payout_request: false)
      _params = {
        'apikey' => api_key,
        'status' => status,
        'p' => page
      }

      endpoint = 'payout/list'

      endpoint = 'payout/request/list' if payout_request

      _payouts = BlockBee::process_request_get(coin, endpoint, params: _params)

      _payouts
    end

    def self.get_payout_wallet(coin, api_key, balance = false)
      wallet = BlockBee::process_request_get(coin, 'payout/address', params: { 'apikey' => api_key })

      if wallet['status'] == 'error'
        raise BlockBee::Error, wallet['error']
      end

      output = { 'address' => wallet['address'] }

      if balance
        wallet_balance = BlockBee::process_request_get(coin, 'payout/balance', params: { 'apikey' => api_key })

        if wallet_balance['status'] == 'error'
          raise BlockBee::Error, wallet_balance['error']
        end

        if wallet_balance['status'] == 'success'
          output['balance'] = wallet_balance['balance']
        end
      end

      output
    end

    def self.create_payout_by_ids(api_key, payout_ids)
      _payout = BlockBee::process_request_post(nil, 'payout/create', api_key, body: { 'request_ids' => payout_ids.join(',') })

      _payout
    end

    def self.process_payout(api_key, payout_id)
      _process = BlockBee::process_request_post(nil, 'payout/process', api_key, body: { 'payout_id' => payout_id })

      _process
    end

    def self.check_payout_status(api_key, payout_id)
      _status = BlockBee::process_request_post(nil, 'payout/status', api_key, body: { 'payout_id' => payout_id })

      _status
    end
  end

  class Checkout
    def initialize(parameters: {}, bb_params: {}, notify_url:, api_key:)
      raise BlockBee::MissingAPIKeyError, 'Provide your API Key' if api_key.nil?

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
      raise ArgumentError, 'Provide a valid number' unless value.is_a?(Numeric)

      _params = {
        'redirect_url' => redirect_url,
        'notify_url' => @notify_url,
        'value' => value,
        'apikey' => @api_key
      }.merge(@bb_params)

      _request = BlockBee::process_request_get(nil, 'checkout/request', params: _params)

      return nil unless _request['status'] == 'success'

      _request
    end

    def self.payment_logs(token, api_key)
      _params = {
        'apikey' => api_key,
        'token' => token
      }

      _logs = BlockBee::process_request_get(nil, 'checkout/logs', params: _params)

      _logs
    end

    def deposit_request
      _params = {
        'notify_url' => @notify_url,
        'apikey' => @api_key
      }.merge(@bb_params)

      _request = BlockBee::process_request_get(nil, 'deposit/request', params: _params)

      _request
    end

    def self.deposit_logs(token, api_key)
      _params = {
        'apikey' => api_key,
        'token' => token
      }

      _logs = BlockBee::process_request_get(nil, 'deposit/logs', params: _params)

      _logs
    end
  end

  private

  def self.process_request_get(coin, endpoint, params: {})
    coin = coin.nil? ? '' : "#{coin.tr('_', '/')}/"

    response = Net::HTTP.get_response(URI.parse("#{BLOCKBEE_URL}#{coin}#{endpoint}/?#{URI.encode_www_form(params)}"))

    response_obj = JSON.parse(response.body)

    if !response.is_a?(Net::HTTPSuccess) || response_obj['status'] == 'error'
      error = APIError.from_status_code(response.code.to_i, response_obj['error'])
      raise error
    end

    response_obj
  end

  def self.process_request_post(coin, endpoint, api_key, body: nil, is_json: false)
    coin_path = coin.nil? ? '' : "#{coin.tr('_', '/')}/"

    url = "#{BLOCKBEE_URL}#{coin_path}#{endpoint}/?apikey=#{api_key}"
    uri = URI.parse(url)

    req = Net::HTTP::Post.new(uri)
    req['Host'] = BLOCKBEE_HOST

    if is_json
      req.content_type = 'application/json'
      req.body = body.to_json
    else
      req.set_form_data(body)
    end

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

    response_obj = JSON.parse(res.body)

    if res.is_a?(Net::HTTPSuccess) && response_obj['status'] == 'success'
      response_obj
    else
      error_message = response_obj['error'] || "Unexpected error occurred"
      error = APIError.from_status_code(res.code.to_i, error_message)
      raise error
    end
  end
end
