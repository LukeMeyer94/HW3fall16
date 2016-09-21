#require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations
require 'timeout'
require 'net/http'

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

   def from_does_not_equal_to
    if @from == @to
      self.errors.add(:from, 'cannot be the same as To')
    end
  end

  def initialize(api_key='')
    if(api_key != nil)
      @api_key = api_key
    else
      raise InvalidKeyError
    end
    # Default to and from
    @from = "Kevin Bacon"
    @to = "Kevin Bacon"
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue OpenURI::HTTPError 
      xml = %q{<?xml version="1.0" standalone="no"?>
<error type="unauthorized">unauthorized use of xml interface</error>}
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      raise NetworkError
      puts e.backtrace
    end
    # your code here: create the OracleOfBacon::Response object
    r = Response.new(xml)
    return r.data
  end

  def make_uri_from_arguments
    # your code here: set the @uri attribute to properly-escaped URI
    # constructed from the @from, @to, @api_key arguments
    tempTo = @to.gsub(' "','52+%22').gsub(' ','+')
    tempFrom = @from.gsub(' "','52+%22').gsub(' ','+')
    
    @uri = "http://oracleofbacon.org/cgi-bin/xml?p=#{@api_key}/&a=#{tempTo}/&b=#{tempFrom}/"
  end
      
  class Response
    attr_reader :type, :data

    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif ! @doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      elsif ! @doc.xpath('/link').empty?
        parse_graph_response
      else
        parse_unknown_response
      end
    end

    def parse_error_response
      temp = @doc.xpath('//error')
      temp = temp.to_s
      if temp.include?("badinput")
        @type = :badinput
        @data = "No query received"
      elsif temp.include?("unlinkable")
        @type = :unlinkable
        @data = "There is no link"
      elsif temp.include?("unauthorized")
        @type = :unauthorized
        @data = "unauthorized"
      end
    end

    def parse_spellcheck_response
      @type = :spellcheck
      @data = @doc.xpath('//match').map(&:text)
      #Note: map(&:text) is same as map{|n| n.text}
    end

    def parse_graph_response
      @type = :graph
      @data = @doc.xpath('//text()').map{ |info|
        info.text
      }
      @data.delete("\n  ")
      @data.delete("\n")
    end

    def parse_unknown_response
      @type = :unknown
      @data = 'Unknown response type'
    end
  end
end
