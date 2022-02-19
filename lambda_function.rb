# Phoxy - Async-pseudo-web-proxy for AWS Lambda
#
# v.20220219

require 'json'
require 'logger'
require 'time'
require_relative './neko-http'
require_relative './phoxy'

STATUS_CODE_OBJ = {statusCode: 200}

def lambda_handler(event:, context:)
  l = Phoxy.logger
  l.error('Pre-flight check failed!') unless preflightcheck
  unless preq = Phoxy::Request.from_event(event)
    l.warn('Received unknown event, dropping request.')
    l.debug("Event:\n#{event}")
    return STATUS_CODE_OBJ
  end
  l.debug("Context: #{preq.context}")
  res = Phoxy.http_request(preq)
  unless res
    l.warn('Request not attempted.')
    return STATUS_CODE_OBJ
  end
  pres = Phoxy.package_response(res, preq)
  l.info("#{Phoxy.return_response(pres)}")
  STATUS_CODE_OBJ
end

def preflightcheck
  l = ENV['PHOXY_LOG_LEVEL']
  if String === l && ['DEBUG', 'INFO', 'WARN', 'ERROR'].include?(l.upcase)
    Phoxy.logger.level = eval("Logger::#{l.upcase}")
  end
  true
end

module Phoxy
  def self.http_request(preq)
    l = Phoxy.logger
    l.debug("Making #{preq.http_method.upcase} to #{preq.url}")
    neko = Neko::HTTP.new(preq.url, preq.http_headers)
    l.debug("#{neko}")
    case preq.http_method
    when :get
      neko.get
    when :post
      neko.post(body: preq.http_body)
    when :put
      neko.put(body: preq.http_body)
    when :patch
      neko.patch(body: preq.http_body)
    when :delete
      neko.delete
    else
      return nil
    end
  end

  def self.package_response(res, preq)
    Response.new({
      context: preq.context,
      url: preq.url,
      return_arn: preq.return_arn,
      http_method: preq.http_method,
      http_body: res[:body],
      http_headers: res[:headers],
      http_status: res[:code],
      message: res[:message],
    })
  end

  def self.return_response(pres)
    l = Phoxy.logger
    return_arn = pres.instance_variable_get(:@return_arn)
    return false if return_arn.nil?
    pl = {
      eventSource: 'Phoxy:response',
      url: pres.url,
      http_status: pres.http_status,
      http_method: pres.http_method,
      http_headers: pres.http_headers,
      http_body: pres.http_body,
      message: pres.message,
      context: pres.context,
    }
    lc = Aws::Lambda::Client.new
    params = {
      function_name: return_arn,
      invocation_type: 'Event',
      payload: JSON.fast_generate({Records: [pl]})
    }
    l.debug("Invoke:\n#{params}")
    r = lc.invoke(params)
    r.status_code # should be 200 series
  end
end
