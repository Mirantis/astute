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
require 'ipaddr'

module Astute
  module Metadata
    def self.publish_facts(ctx, uid, metadata, options={})
      fake = options['fake']
      if fake
        fname = "/tmp/astute_facts_node_#{uid}"
        Astute.logger.info("#{ctx.task_id}: publish facts into file #{fname}")
        write_facts(fname, metadata.to_json)
        return
      end
      # This is synchronious RPC call, so we are sure that data were sent and processed remotely
      Astute.logger.info "#{ctx.task_id}: nailyfact - storing metadata for node uid=#{uid}"
      Astute.logger.debug "#{ctx.task_id}: nailyfact stores metadata: #{metadata.inspect}"
      nailyfact = MClient.new(ctx, "nailyfact", [uid])
      # TODO(mihgen) check results!
      stats = nailyfact.post(:value => metadata.to_json)
    end

    def self.write_facts(fname, metadata_json)
      begin
        facts = JSON.parse(metadata_json)

        if not File.exists?(File.dirname(fname))
          Dir.mkdir(File.dirname(fname))
        end

        f = File.open(fname, "w+")
        facts.each do |k,v|
          f.puts("#{k} = #{v}")
        end
        f.close
      rescue => e
        Astute.logger.error("Exception occured while writing facts to file: \
          filename: #{fname} message: #{e.message} traceback: #{e.backtrace.inspect}")
      end
    end
  end
end
