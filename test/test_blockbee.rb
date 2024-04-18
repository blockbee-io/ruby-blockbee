# frozen_string_literal: true

require "test_helper"

class TestBlockBee < Minitest::Test
  API_KEY = # '<api-key-here>'
  COIN = 'bep20_usdt'
  OWN_ADDRESS = ''
  CALLBACK_URL = 'https://webhook.site/ef8e2859-12a9-4028-8a94-51582e83dd05'
  PARAMETERS = {
    'order_id': 13435
  }
  BB_PARAMETERS = {
    'convert': 1,
    'multi_token': 1
  }

  # Tested 18/04/2024 -> All tests OK.

  def test_that_it_has_a_version_number
    refute_nil ::BlockBee::VERSION
  end

  def test_can_generate_address
    blockbee_helper = BlockBee::API.new(COIN, CALLBACK_URL, API_KEY, parameters: PARAMETERS, bb_params: BB_PARAMETERS)

    address = blockbee_helper.get_address
    p address
    refute_nil address['address_in']
  end

  def test_can_fetch_logs
    blockbee_helper = BlockBee::API.new(COIN, CALLBACK_URL, API_KEY, parameters: PARAMETERS, bb_params: BB_PARAMETERS)

    logs = blockbee_helper.get_logs
    p logs
    refute_nil logs
  end

  def test_can_get_qrcode
    blockbee_helper = BlockBee::API.new(COIN, CALLBACK_URL, API_KEY, parameters: PARAMETERS, bb_params: BB_PARAMETERS)

    qrcode = blockbee_helper.get_qrcode(value: 10, size: 300)
    p qrcode
    refute_nil qrcode
  end

  def test_can_get_conversion
    blockbee_helper = BlockBee::API.new(COIN, CALLBACK_URL, API_KEY, parameters: PARAMETERS, bb_params: BB_PARAMETERS)

    conversion = blockbee_helper.get_conversion('btc', 10)
    p conversion
    refute_nil conversion
  end

  def test_can_get_info
    info = BlockBee::API.get_info('btc', prices: 1)
    p info
    refute_nil info
  end

  def test_can_get_supported_coins
    supported_coins = BlockBee::API.get_supported_coins
    p supported_coins
    refute_nil supported_coins
  end

  def test_can_get_estimate
    estimate = BlockBee::API.get_estimate('btc', API_KEY)
    # p estimate
    refute_nil estimate
  end

  def test_can_create_payouts
    payouts = BlockBee::API.create_payout('bep20_usdt', {
      '0xA6B78B56ee062185E405a1DDDD18cE8fcBC4395d' => 0.5
    }, API_KEY, process: false)

    p payouts

    refute_nil payouts
  end

  def test_can_list_payouts
    payouts_list = BlockBee::API.list_payouts('bep20_usdt', API_KEY, status: 'all', page: 1, payout_request: true)
    p payouts_list
    refute_nil payouts_list
  end

  def test_can_get_payout_wallet
    wallet = BlockBee::API.get_payout_wallet('polygon_matic', API_KEY, true)
    p wallet
    refute_nil wallet
  end

  def test_can_create_payout_by_is
    creating = BlockBee::API.create_payout_by_ids(API_KEY, [
      52240, 52239 # Make sure these values are valid Payout Request IDs otherwise it will fail
    ])
    p creating
    refute_nil creating
  end

  def test_can_process_payout_by_id
    process = BlockBee::API.process_payout(API_KEY, 2597)
    p process
    refute_nil process
  end

  def test_can_check_payout_status
    status = BlockBee::API.check_payout_status(API_KEY, 2596)
    p status
    refute_nil status
  end

  def test_can_create_checkout_payment
    blockbee_helper = BlockBee::Checkout.new(api_key: API_KEY, notify_url: CALLBACK_URL, bb_params: {
      'item_description' => 'Ruby test'
    }, parameters: {
      'payment_id': 123
    })
    payment = blockbee_helper.payment_request(CALLBACK_URL, 2)
    p payment
    refute_nil payment
  end

  def test_can_create_deposit
    blockbee_helper = BlockBee::Checkout.new(api_key: API_KEY, notify_url: CALLBACK_URL, bb_params: {
      'item_description' => 'Ruby test'
    }, parameters: {
      'payment_id': 123
    })
    deposit = blockbee_helper.deposit_request
    p deposit
    refute_nil deposit
  end

  def test_can_fetch_payment_logs
    logs = BlockBee::Checkout.payment_logs('SvWOxynRVxBu2R3uM5kDnzrnQAY2SMl3', API_KEY)
    p logs
    refute_nil logs
  end

  def test_can_fetch_deposit_logs
    logs = BlockBee::Checkout.deposit_logs('DmKinE0BU8uJuVqsDXRkU2JMlItohliH', API_KEY)
    p logs
    refute_nil logs
  end
end