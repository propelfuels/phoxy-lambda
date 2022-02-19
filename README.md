# phoxy-lambda

Async-pseudo-web-proxy for AWS Lambda

Use case: set up **phoxy** as a Lambda function to run in a VPC private subnet and allow functions not in the same VPC to access resources.

## Setup

1. Create a Lambda function for **phoxy**
  - Make sure IAM role has permission to invoke functions expecting response returns
1. Copy `phoxy.rb` to requesting Lambda functions and `require`
  - Make sure IAM role has permission to invoke **phoxy**

## Usage

### Sending a Request

From a Lambda function, prepare a request and invoke **phoxy**.

```ruby
require_relative './phoxy'
# ...
params = {
  url: 'http://id:pass@example.com:80/path?q=keyword',
  http_method: :post,
  http_headers: {"content-type": "application/json"},
  http_body: "{\"message\":\"Hello!\"}",
  return_arn: context.invoked_function_arn,
  context: "some string..."
}
preq = Phoxy::Request.new(params)
preq.send_to_arn('aws:lambda:us:12345:my-phoxy')
```

**phoxy** will process the request and return a response if `return_arn` is set.

### Receiving a Response

Just pass the `event` object the handler receives. If it is not a `Phoxy::Response` it will return `nil`.

```ruby
require_relative './phoxy'
# ...
pres = Phoxy::Response.from_event(event)
if pres
  puts JSON.parse(pres.http_body)
else
  # When it's not a Phoxy::Response
end
```

`Phoxy::Response` structure example.

```ruby
pres.url          # => 'http://id:pass@example.com:80/path?q=keyword'
pres.context      # => 'some string...'
pres.http_status  # => 200
pres.http_headers # => {
                  #      "date": ["Sun, 13 Feb 2022 01:23:45 GMT"],
                  #      "content-type": ["application/json"],
                  #      "content-length": ["678"]
                  #    }
```
