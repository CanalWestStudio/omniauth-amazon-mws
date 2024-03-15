module OmniAuth
  module Strategies
    class Amazon
      include OmniAuth::Strategies

      option :name, 'amazon'

      args [:app_id, :aws_key, :secret_key]
      
      option :app_id, nil
      option :aws_key, nil
      option :secret_key, nil

      uid { raw_info[:Merchant] }

      info do
        {
          'seller_id' => raw_info['Merchant'],
          'marketplace_id' => raw_info['Marketplace'],
          'raw_info' => raw_info
        }
      end

      def request_phase
        redirect activation_url
      rescue => ex
        fail!("Failed to connect to Amazon", ex)
      end

      def callback_phase
        @response = request.params
        super
      rescue => ex
        fail!("Failed to retrieve user info from Amazon", ex)
      end

      def raw_info
        @response
      end

      def activation_url
        url = {
          :endpoint => 'sellercentral.amazon.com',
          :host => '/gp/mws/registration/register.html'
        }

        params = {
          :id => options.app_id,
          :AWSAccessKeyId => options.aws_key,
          :SignatureMethod => 'HmacSHA256',
          :SignatureVersion => 2,
          :returnPathAndParameters => callback_path
        }

        params[:Signature] = amazon_signature_v2( params, url, options.secret_key )

        url = "https://#{url[:endpoint]}#{url[:host]}?#{sorted_query(params)}";
      end

      # alphabetize query
      def sorted_query(hash)
        params = hash.sort.map do |arr|
          key = Rack::Utils.escape(arr[0])
          val = Rack::Utils.escape(arr[1])
          "#{key}=#{val}"
        end
        query_str = params.join("&")
      end


      def amazon_signature_v2( params, url, secret_key )
        #create alphabetized query string from params
        query_str = sorted_query(params)

        data = ['GET', url[:endpoint], url[:host], query_str].join("\n")

        sha256 = OpenSSL::Digest::SHA256.new
        sig = OpenSSL::HMAC.digest(sha256, secret_key, data)
        signature = Base64.strict_encode64(sig)
      end
    end
  end
end
