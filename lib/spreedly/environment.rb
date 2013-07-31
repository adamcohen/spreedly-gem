require 'base64'
require 'nokogiri'

module Spreedly
  class Environment

    include SslRequester
    include Urls

    attr_reader :key, :currency_code

    def initialize(environment_key, access_secret, options={})
      @key, @access_secret = environment_key, access_secret
      @currency_code = options[:currency_code] || 'USD'
    end

    def transparent_redirect_form_action
      "#{base_url}/v1/payment_methods"
    end

    def find_payment_method(token)
      xml_doc = ssl_get(find_payment_method_url(token), headers)
      PaymentMethod.new_from(xml_doc)
    end

    def purchase_on_gateway(gateway_token, payment_method_token, amount, options = {})
      body = auth_purchase_body(amount, payment_method_token, options)
      xml_doc = ssl_post(purchase_url(gateway_token), body, headers)
      Transaction.new_from(xml_doc)
    end

    def add_credit_card(options)
      body = add_credit_card_body(options)
      xml_doc = ssl_post(add_payment_method_url, body, headers)
      Transaction.new_from(xml_doc)
    end

    def add_gateway(gateway_type, options = {})
      body = add_gateway_body(gateway_type, options)
      xml_doc = ssl_post(add_gateway_url, body, headers)
      Gateway.new(xml_doc)
    end

    private
    def headers
      {
        'Authorization' => ('Basic ' + Base64.strict_encode64("#{@key}:#{@access_secret}").chomp),
        'Content-Type' => 'text/xml'
      }
    end

    def auth_purchase_body(amount, payment_method_token, options)
      build_xml_request('transaction') do |doc|
        doc.amount amount
        doc.currency_code(options[:currency_code] || currency_code)
        doc.payment_method_token(payment_method_token)
      end
    end

    def add_gateway_body(gateway_type, options)
      build_xml_request('gateway') do |doc|
        doc.gateway_type gateway_type
      end
    end

    def add_credit_card_body(options)
      build_xml_request('payment_method') do |doc|
        doc.email options[:email]
        doc.retained options[:retained] if options[:retained]
        doc.credit_card do
          doc.number options[:number]
          doc.month options[:month]
          doc.first_name options[:first_name]
          doc.last_name options[:last_name]
          doc.year options[:year]
        end
      end
    end

    def build_xml_request(root)
      builder = Nokogiri::XML::Builder.new
      builder.__send__(root) do |doc|
        yield(doc)
      end
      builder.to_xml
    end

  end
end
