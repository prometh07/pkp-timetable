#!/usr/bin/env ruby
#encoding: utf-8
require 'date'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'micro-optparse'


class Query
  def initialize
    uri = URI.parse('http://rozklad-pkp.pl')
    @http = Net::HTTP.new(uri.host, uri.port)
  end

  def get(path, args)
    full_path = encode_path_params(path, args)
    @http.get(full_path)
  end

  def station_code(station)
    response = get('/station/search', term: station)
    stations = JSON.parse(response.body)
    stations.length == 1 ? stations.first['value'] : raise("Ambiguous station name: #{station}")
  end

  def encode_path_params(path, args={})
    encoded = URI.encode_www_form(args)
    [path, encoded].join('?')
  end

  def timetable(from, to, date, hour)
    args = {
      REQ0HafasChangeTime: '0:1',
      REQ0HafasSearchForw: 1,
      REQ0JourneyDate: date,
      REQ0JourneyProduct_opt_section_0_list: '0:000000',
      REQ0JourneyStopsS0A: 1,
      REQ0JourneyStopsS0G: station_code(from),
      REQ0JourneyStopsZ0A: 1,
      REQ0JourneyStopsZ0G: station_code(to),
      REQ0JourneyTime: hour,
      came_from_form: 1,
      date: date,
      dateEnd: date,
      dateStart: date,
      existBikeEverywhere: 'yes',
      existHafasAttrExc: 'yes',
      existHafasAttrInc: 'yes',
      existOptimizePrice: 1,
      existSkipLongChanges: 0,
      existUnsharpSearch: 'yes',
      start: 'start',
      time: hour,
      wDayExt0: 'Pn|Wt|Śr|Cz|Pt|So|Nd'
    }

    response = get('/pl/tp', args)
    trains = parse_timetable_html(response.body)

    puts "\nDATE: #{date}"
    puts "FROM: #{from} TO: #{to}\n"
    puts ['Departure', 'Arrival', 'Train'].map { |s| s.ljust(12) }.join
    trains.each {|t| puts t.map { |s| s.ljust(12) }.join }
    puts
  end

  def parse_timetable_html(html)
    Nokogiri::HTML(html).css('#wyniki tr').map do |row|
      [*row.text.scan(/ODJAZD(\d{2}:\d{2}).*PRZYJAZD(\d{2}:\d{2})/).flatten,
       (row.css('img').first.attr('alt') rescue next)]
    end.compact
  end
end


class Options
  def self.initialize
    opts = Parser.new do |p|
       p.banner = "PKP timetable"
       p.option :from, 'departure station', default: ENV['DEPARTURE_STATION'] || ''
       p.option :to, 'target station', default: ENV['TARGET_STATION'] || ''
       p.option :hour, 'departure hour', default: Time.now.strftime('%H:%M')
       p.option :date, 'departure date', default: Time.now.strftime('%d.%m.%y')
       p.option :reverse, 'reverse stations', default: false
       p.option :next_day, 'next day', default: false
       p.option :previous_day, 'previous day', default: false
    end.process!

    if opts[:reverse]
      opts[:from], opts[:to] = opts[:to], opts[:from]
    end
    if opts[:next_day]
      opts[:date] = Date.today.next_day.strftime('%d.%m.%y')
    elsif opts[:previous_day]
      opts[:date] = Date.today.prev_day.strftime('%d.%m.%y')
    end

    opts
  end
end


opts = Options.initialize
Query.new.timetable(opts[:from], opts[:to], opts[:date], opts[:hour])
