#    Copyright 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.


require 'json'

module MCollective
  module Agent
    class Nailyfact<RPC::Agent
      nailyfile = "/etc/naily.facts"

      def parse_facts(fname)
        begin
          if File.exist?(fname)
            kv_map = {}
            File.readlines(fname).each do |line|
              if line =~ /^(.+)=(.+)$/    
                @key = $1.strip;                 
                @val = $2.strip               
                kv_map.update({@key=>@val})
              end                      
            end                  
            return kv_map
          else
            f = File.open(fname,'w')
            f.close
            File.open("/var/log/facter.log", "a") {|f| f.write("#{Time.now} EMPTY facts saved\n")}
            return {}
          end             
        rescue
          logger.warn("Could not access naily facts file. There was an error in nailyfacts.rb:parse_facts")
          return {}
        end
      end

      def write_facts(fname, facts)
        if not File.exists?(File.dirname(fname))
          Dir.mkdir(File.dirname(fname))
        end

        begin
          f = File.open(fname,"w+")
          facts.each do |k,v|
            f.puts("#{k} = #{v}")
          end
          f.close
          File.open("/var/log/facter.log", "a") {|f| f.write("#{Time.now} facts saved\n")}
          return true
        rescue
          File.open("/var/log/facter.log", "a") {|f| f.write("#{Time.now} facts NOT saved\n")}
          return false
        end
      end

      action "get" do
        validate :key, String
        kv_map = parse_facts(nailyfile)
        if kv_map[request[:key]] != nil
          reply[:value] = kv_map[request[:key]]
        end
      end

      action "post" do
        validate :value, String

        kv_map = JSON.parse(request[:value])

        if write_facts(nailyfile, kv_map)
          reply[:msg] = "Settings Updated!"
        else
          reply.fail! "Could not write file!"
        end
      end
    end
  end
end
