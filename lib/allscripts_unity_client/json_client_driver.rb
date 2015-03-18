require 'multi_json'
require 'faraday'
require 'httpclient'

module AllscriptsUnityClient

  # A ClientDriver that supports Unity's JSON endpoints.
  class JSONClientDriver < ClientDriver
    attr_accessor :json_base_url, :connection

    UNITY_JSON_ENDPOINT = '/Unity/UnityService.svc/json'

    def initialize(options)
      super
      @connection = Faraday.new(build_faraday_options) do |conn|
        conn.adapter :httpclient
      end
    end

    def client_type
      :json
    end

    def magic(parameters = {})
      request_data = JSONUnityRequest.new(parameters, @options.timezone, @options.appname, @security_token)

      response = @connection.post do |request|
        request.url "#{UNITY_JSON_ENDPOINT}/MagicJson"
        request.headers['Content-Type'] = 'application/json'
        request.body = MultiJson.dump(request_data.to_hash)
        set_request_timeout(request)
        start_timer
      end
      end_timer

      response = MultiJson.load(response.body)

      raise_if_response_error(response)
      log_magic(request_data)

      response = JSONUnityResponse.new(response, @options.timezone)
      response.to_hash
    end

    # See Client#get_security_token!.
    def get_security_token!(parameters = {})
      username = parameters[:username] || @options.username
      password = parameters[:password] || @options.password
      appname = parameters[:appname] || @options.appname

      request_data = {
        'Username' => username,
        'Password' => password,
        'Appname' => appname
      }

      response = @connection.post do |request|
        request.url "#{UNITY_JSON_ENDPOINT}/GetToken"
        request.headers['Content-Type'] = 'application/json'
        request.body = MultiJson.dump(request_data)
        set_request_timeout(request)
        start_timer
      end
      end_timer

      raise_if_response_error(response.body)
      log_get_security_token

      @security_token = response.body
    end

    # See Client#retire_security_token!.
    def retire_security_token!(parameters = {})
      token = parameters[:token] || @security_token
      appname = parameters[:appname] || @options.appname

      request_data = {
        'Token' => token,
        'Appname' => appname
      }

      response = @connection.post do |request|
        request.url "#{UNITY_JSON_ENDPOINT}/RetireSecurityToken"
        request.headers['Content-Type'] = 'application/json'
        request.body = MultiJson.dump(request_data, mode: :compat)
        set_request_timeout(request)
        start_timer
      end
      end_timer

      raise_if_response_error(response.body)
      log_retire_security_token

      @security_token = nil
    end

    private

    def raise_if_response_error(response)
      if response.nil?
        raise APIError, 'Response was empty'
      elsif response.is_a?(Array) && !response[0].nil? && !response[0]['Error'].nil?
        raise APIError, response[0]['Error']
      elsif response.is_a?(String) && response.include?('error:')
        raise APIError, response
      end
    end

    def build_faraday_options
      options = {}

      # Configure Faraday base url
      options[:url] = @options.base_unity_url

      # Configure root certificates for Faraday using options or via auto-detection
      if @options.ca_file?
        options[:ssl] = { ca_file: @options.ca_file }
      elsif @options.ca_path?
        options[:ssl] = { ca_path: @options.ca_path }
      elsif ca_file = JSONClientDriver.find_ca_file
        options[:ssl] = { ca_file: ca_file }
      elsif ca_path = JSONClientDriver.find_ca_path
        options[:ssl] = { ca_path: ca_path }
      end

      # Configure proxy
      if @options.proxy?
        options[:proxy] = @options.proxy
      end

      options
    end

    def self.find_ca_path
      if File.directory?('/usr/lib/ssl/certs')
        return '/usr/lib/ssl/certs'
      end

      nil
    end

    def self.find_ca_file
      if File.exists?('/usr/lib/ssl/certs/ca-certificates.crt')
        return '/usr/lib/ssl/certs/ca-certificates.crt'
      end

      nil
    end

    def set_request_timeout(request)
      if @options.timeout?
        request.options[:timeout] = @options.timeout
        request.options[:open_timeout] = @options.timeout
      else
        request.options[:timeout] = 90
        request.options[:open_timeout] = 90
      end
    end
  end
end
