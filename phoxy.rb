# Phoxy - Async-pseudo-web-proxy for AWS Lambda
#      ::Request - requester-side classes
#
# v.20220219

require 'aws-sdk-lambda'
require 'json'

module Phoxy
  def self.logger=(logger)
    @logger = logger
  end

  def self.logger
    @logger ||= Logger.new($stdout, formatter: proc { |s, d, n, m| "#{s} : #{m}\n" })
  end

  class Request
    def self.default_lambda_arn
      @default_lambda_arn
    end

    def self.default_lambda_arn=(arn)
      raise TypeError, "given #{arn.class}, expecting String" unless String === arn
      @default_lambda_arn = arn
    end

    def self.from_event(event)
      l = Phoxy.logger
      return nil unless event.dig('Records', 0, 'eventSource') == 'Phoxy:request'
      r = event['Records'].first
      params = r.transform_keys{ |k| k.to_sym }
      new(params)
    end

    attr_accessor  :context, :http_body, :http_headers, :http_method, :return_arn, :url

    def initialize(params = nil)
      return if params.nil?
      raise TypeError, "given #{params.class}, expecting Hash" unless Hash === params
      params.each do |k, v|
        # instance_variable_set("@#{k}", v) if respond_to?("#{k}=")
        public_send("#{k}=", v) if respond_to?("#{k}=")
      end
    end

    def http_method=(m)
      @http_method = (String === m ? m.to_sym : m)
    end

    # @param arn [String] Lambda ARN to send the request
    # @return [Integer] 202 for success
    def send_to_arn(arn = nil)
      raise '@url not set' unless @url
      pl = {
        eventSource: 'Phoxy:request',
        url: @url,
        http_method: (@http_method ? @http_method : :get),
        http_headers: @http_headers,
        http_body: @http_body,
        return_arn: @return_arn,
        context: @context,
      }
      lc = Aws::Lambda::Client.new
      arn ||= Request.default_lambda_arn
      raise 'arn not set' unless arn
      params = {
        function_name: arn,
        invocation_type: 'Event',
        payload: JSON.fast_generate({Records: [pl]})
      }
      r = lc.invoke(params)
      r.status_code # should be 200 series
    end
  end

  class Response
    def self.from_event(event)
      l = Phoxy.logger
      return nil unless event.dig('Records', 0, 'eventSource') == 'Phoxy:response'
      r = event['Records'].first
      params = r.transform_keys{ |k| k.to_sym }
      new(params)
    end

    attr_reader :context, :http_body, :http_headers, :http_method, :http_status
    attr_reader :message, :url

    def initialize(params)
      raise TypeError, "given #{params.class}, expecting Hash" unless Hash === params
      params.each do |k, v|
        instance_variable_set("@#{k}", (k == :http_method ? v.to_sym : v))
      end
    end
  end
end
