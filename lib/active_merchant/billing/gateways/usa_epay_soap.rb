require "paysimple"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
        
    class UsaEpaySoapGateway < Gateway
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.supported_countries = ['US']
      self.homepage_url = 'http://www.usaepay.com/'
      self.display_name = 'USA ePay'

      def initialize(options = {})
        requires!(options, :login)
        requires!(options, :password)
        @options = options
        
        PaySimple.key = options[:login]
        PaySimple.pin = options[:password]
        
        super
      end  
      
      def store(creditcard, options = {})
      
        @error = nil
        begin
          @paysimple_response = PaySimple::Subscription.create(
            :CustomerID  => "#{Time.now.to_i}#{rand(999999)}",
            :BillingAddress => {
              :FirstName => creditcard.first_name,
              :LastName => creditcard.last_name
            },
            :CreditCardData => {
              :CardNumber => creditcard.number,
              :CardExpiration => expdate(creditcard)
            }, 
            :Schedule => :monthly,
            :Next => "2008-09-05", # in the past, paysimple seems to need this
            :Enabled => false
          )
        rescue Exception => @error
          puts "An error occurred: #{@error.message}"
        end
        
        success = @error ? false : true
        
        message = @paysimple_response
        if @error
          message = @error
        end
        
        USAEpaySoapResponse.new(success == true, message, {:token => @paysimple_response})
        
      end
      
      def purchase(money, customer_number, options = {})
        success = false
        begin
          
          @paysimple_response = PaySimple::Subscription.charge(customer_number, :Amount => sprintf("%.2f", money.to_f/100))
          
          if @paysimple_response["Result"] == "Approved"
            success = true
          end
        rescue Exception => @error
          puts "An error occurred: #{@error.message}"
        end
        
        parse_paysimple_response(success, @paysimple_response) 
        
      end
      
      def unstore(customer_number, options={})
        @error = nil
        begin
          @paysimple_response = PaySimple::Subscription.delete(customer_number)
        
          puts "Subscription removed from active use."
        rescue Exception => @error
          puts "An error occurred: #{@error.message}"
        end

        success = @error ? false : true
        message = @paysimple_response
        if @error
          message = @error
        end
        
        USAEpaySoapResponse.new(success == true, message, {:token => @paysimple_response})
        
      end
       
      def update(customer_number, creditcard, options = {})
        @error = nil
        begin
          @paysimple_response = PaySimple::Subscription.update(
            customer_number,
            :CreditCardData => {
              :CardNumber => creditcard.number,
              :CardExpiration => expdate(creditcard)
            }
          )

        rescue Exception => @error
          puts "An error occurred: #{@error.message}"
        end
        
        success = @error ? false : true
        
        parse_paysimple_response(success, @paysimple_response.to_s) 

      end
      
      private                       
      
      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{month}#{year}"
      end
      
      def message_from(response)
        if response[:Result] == "Approved"
          return 'Success'
        else
          return 'Unspecified error' if response[:Error].blank?
          return response[:Error]
        end
      end
      
      def parse_paysimple_response(success, paysimple_response, params={})
        paysimple_response = {} if paysimple_response.nil?
        
        USAEpaySoapResponse.new(success == true, message_from(paysimple_response), params, 
          :authorization => paysimple_response["RefNum"],
          :cvv_result => paysimple_response["CardCodeResult"],
          :avs_result => { :code => paysimple_response["AvsResultCode"] }
        )
      end
      
    end
    
    class USAEpaySoapResponse < Response
      # add a method to response so we can easily get the token
      # for vault transactions
      def token
        @params["token"]
      end
    end
    
  end
end

