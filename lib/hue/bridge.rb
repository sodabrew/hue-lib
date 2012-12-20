require 'digest/md5'
require 'uuid'
require 'singleton'

module Hue
  class Bridge
    include Singleton

    # Remove
    def self.method_missing(method, *args, &block)
      if args.empty?
        self.instance.send method
      else
        self.instance.send method, *args
      end
    end

    # Move to APP class
    def self.register(host = BASE)
      # TODO: Look for defult config.
      puts "Please press the button on bridge before continuing."
      puts "Once done, press Enter to continue."
      gets
      secret = Digest::MD5.hexdigest(UUID.generate) # one time UUID
      puts "Registering app...(#{secret})"
      config = Hue::Config.new(host, secret)
      instance.create(
        URI.parse(config.base_uri),
        {"username" => config.base_uri, "devicetype" => Hue.device_type}
      )
      config.write
    end

    # Move to APP class
    def self.remove
      config = Config.default
      instance.delete(
        URI.parse(config.base_uri),
        {"username" => config.identifier}
      )
      config.delete
    end

    public

    def initialize()
    end

    def status
      JSON.parse Net::HTTP.get(Bridge.instance.uri)
    end

    def lights
      status['lights']
    end

    def identities
      Hash[lights.map{|k, v| [k, v['name']] }]
    end

    def bulbs
      @bulbs ||= lights.keys.map{|b| Bulb.new b}
    end

    def reload
      @bulbs = nil
      self
    end

    def schedules
      status['schedules']
    end

    def remove_schedule(schedule_id)
      delete uri('schedules', schedule_id)
      puts "Removed schedule #{schedule_id}"
    end

    def remove_all_schedules
      ids = schedules.keys.map(&:to_i).sort.reverse
      puts "Removing #{ids.size} schedule#{'s' if ids.size != 1}..."
      ids.each{|x| remove_schedule x}
    end

    def uri(*args)
      URI [BASE, UUID, args].flatten.reject{|x| x.to_s.strip == ''}.join('/')
    end

    public

    def update(url, settings = {})
      request = Net::HTTP::Put.new(url.request_uri, initheader = {'Content-Type' =>'application/json'})
      request.body = settings.to_json
      display Net::HTTP.new(url.host, url.port).start {|http| http.request(request) }
    end

    def delete(url, settings = {})
      request = Net::HTTP::Delete.new(url.request_uri, initheader = {'Content-Type' =>'application/json'})
      request.body = settings.to_json
      display Net::HTTP.new(url.host, url.port).start{|http| http.request(request)}
    end

    def create(url, settings = {})
      request = Net::HTTP::Post.new(url.request_uri, initheader = {'Content-Type' =>'application/json'})
      request.body = settings.to_json
      display Net::HTTP.new(url.host, url.port).start {|http| http.request(request) }
    end

    private

    def display(response = nil)
      if response and response.code.to_s != '200'
        # Output to logger
        puts "Response #{response.code} #{response.message}: #{JSON.parse(response.body).first}"
        false
      else
        # Output to logger
        puts "Response #{response.code} #{response.message}: #{JSON.parse(response.body).first}"
        true
      end
    end

  end
end
