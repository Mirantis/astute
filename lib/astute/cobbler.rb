require 'xmlrpc/client'

module Astute
  module Provision
    class CobblerError < RuntimeError; end

    class Cobbler

      attr_reader :remote, :token

      def initialize(o={})
        Astute.logger.debug("Cobbler options: #{o.inspect}")

        if (match = /^http:\/\/([^:]+?):?(\d+)?(\/.+)/.match(o['url']))
          host = match[1]
          port = match[2] || '80'
          path = match[3]
        else
          host = o['host'] || 'localhost'
          port = o['port'] || '80'
          path = o['path'] || '/cobbler_api'
        end
        username = o['username'] || 'cobbler'
        password = o['password'] || 'cobbler'

        Astute.logger.debug("Connecting to cobbler with: host: #{host} port: #{port} path: #{path}")
        @remote = XMLRPC::Client.new(host, path, port)
        Astute.logger.debug("Trying to log in to cobbler with username: #{username}, password: #{password}")
        @token = remote.call('login', username, password)
      end

      def item_from_hash(what, name, data, opts = {})
        options = {
          :item_preremove => true,
        }.merge!(opts)
        cobsh = Cobsh.new(data.merge({'what' => what, 'name' => name}))
        cobblerized = cobsh.cobblerized

        Astute.logger.debug("Creating/editing item from hash: #{cobsh.inspect}")
        remove_item(what, name) if options[:item_preremove]
        # get existent item id or create new one
        item_id = get_item_id(what, name)

        # defining all item options
        cobblerized.each do |opt, value|
          next if opt == 'interfaces'
          Astute.logger.debug("Setting #{what} #{name} opt: #{opt}=#{value}")
          remote.call('modify_item', what, item_id, opt, value, token)
        end

        # defining system interfaces
        if what == 'system' && cobblerized.has_key?('interfaces')
          Astute.logger.debug("Defining system interfaces #{name} #{cobblerized['interfaces']}")
          remote.call('modify_system', item_id, 'modify_interface',
                  cobblerized['interfaces'], token)
        end

        # save item into cobbler database
        Astute.logger.debug("Saving #{what} #{name}")
        remote.call('save_item', what, item_id, token)
      end

      def remove_item(what, name, recursive=true)
        remote.call('remove_item', what, name, token, recursive) if item_exists(what, name)
      end

      def remove_system(name)
        remove_item('system', name)
      end

      def item_exists(what, name)
        remote.call('has_item', what, name)
      end

      def system_exists(name)
        item_exists('system', name)
      end

      def get_item_id(what, name)
        if item_exists(what, name)
          item_id = remote.call('get_item_handle', what, name, token)
        else
          item_id = remote.call('new_item', what, token)
          remote.call('modify_item', what, item_id, 'name', name, token)
        end
        item_id
      end

      def sync
        remote.call('sync', token)
      end

      def power(name, action)
        options = {"systems" => [name], "power" => action}
        remote.call('background_power_system', options, token)
      end

      def power_on(name)
        power(name, 'on')
      end

      def power_off(name)
        power(name, 'off')
      end

      def power_reboot(name)
        power(name, 'reboot')
      end

    end

    class Cobsh < ::Hash
      ALIASES = {
        'ks_meta' => ['ksmeta'],
        'mac_address' => ['mac'],
        'ip_address' => ['ip'],
      }

      # these fields can be get from the cobbler code
      # you can just import cobbler.item_distro.FIELDS
      # or cobbler.item_system.FIELDS
      FIELDS = {
        'system' => {
          'fields' => [
            'name', 'owners', 'profile', 'image', 'status', 'kernel_options',
            'kernel_options_post', 'ks_meta', 'enable_gpxe', 'proxy',
            'netboot_enabled', 'kickstart', 'comment', 'server',
            'virt_path', 'virt_type', 'virt_cpus', 'virt_file_size',
            'virt_disk_driver', 'virt_ram', 'virt_auto_boot', 'power_type',
            'power_address', 'power_user', 'power_pass', 'power_id',
            'hostname', 'gateway', 'name_servers', 'name_servers_search',
            'ipv6_default_device', 'ipv6_autoconfiguration', 'mgmt_classes',
            'mgmt_parameters', 'boot_files', 'fetchable_files',
            'template_files', 'redhat_management_key', 'redhat_management_server',
            'repos_enabled', 'ldap_enabled', 'ldap_type', 'monit_enabled',
          ],
          'interfaces_fields' => [
            'mac_address', 'mtu', 'ip_address', 'interface_type',
            'interface_master', 'bonding_opts', 'bridge_opts',
            'management', 'static', 'netmask', 'dhcp_tag', 'dns_name',
            'static_routes', 'virt_bridge', 'ipv6_address', 'ipv6_secondaries',
            'ipv6_mtu', 'ipv6_static_routes', 'ipv6_default_gateway'
          ],
          'special' => ['interfaces', 'interfaces_extra']
        },
        'profile' => {
          'fields' => [
            'name', 'owners', 'distro', 'parent', 'enable_gpxe',
            'enable_menu', 'kickstart', 'kernel_options', 'kernel_options_post',
            'ks_meta', 'proxy', 'repos', 'comment', 'virt_auto_boot',
            'virt_cpus', 'virt_file_size', 'virt_disk_driver',
            'virt_ram', 'virt_type', 'virt_path', 'virt_bridge',
            'dhcp_tag', 'server', 'name_servers', 'name_servers_search',
            'mgmt_classes', 'mgmt_parameters', 'boot_files', 'fetchable_files',
            'template_files', 'redhat_management_key', 'redhat_management_server'
          ]
        },
        'distro' => {
          'fields' => ['name', 'owners', 'kernel', 'initrd', 'kernel_options',
            'kernel_options_post', 'ks_meta', 'arch', 'breed',
            'os_version', 'comment', 'mgmt_classes', 'boot_files',
            'fetchable_files', 'template_files', 'redhat_management_key',
            'redhat_management_server']
        }

      }

      def initialize(h)
        Astute.logger.debug("Cobsh is initialized with: #{h.inspect}")
        raise CobblerError, "Cobbler hash must have 'name' key" unless h.has_key? 'name'
        raise CobblerError, "Cobbler hash must have 'what' key" unless h.has_key? 'what'
        raise CobblerError, "Unsupported 'what' value" unless FIELDS.has_key? h['what']
        h.each{|k, v| store(k, v)}
      end


      def cobblerized
        Astute.logger.debug("Cobblerizing hash: #{inspect}")
        ch = {}
        ks_meta = ""

        each do |k, v|
          k = aliased(k)
          if ch.has_key?(k) && ch[k] == v
            next
          elsif ch.has_key?(k)
            raise CobblerError, "Wrong cobbler data: #{k} is duplicated"
          end

          # skiping not valid item options
          unless valid_field?(k)
            Astute.logger.debug("Key #{k} is not valid. Will be skipped.")
            next
          end

          # here we don't store ks_meta directly in ch (cobblerized hash)
          # instead we just append ks_meta value to store it later
          if k == 'ks_meta'
            if v.kind_of?(Hash)
              v.each do |ks_meta_key, ks_meta_value|
                ks_meta << " #{ks_meta_key}=#{ks_meta_value}"
              end
            elsif v.kind_of?(String)
              ks_meta << " #{v}"
            else
              raise "Wrong ks_meta format. It must be Hash or String"
            end
          end

          # special handling for system interface fields
          # which are the only objects in cobbler that will ever work this way
          if k == 'interfaces'
            ch.store('interfaces', cobblerized_interfaces)
            next
          end

          # here we convert interfaces_extra options into ks_meta format
          if k == 'interfaces_extra'
            ks_meta << cobblerized_interfaces_extra
            next
          end

          ch.store(k, v)
        end # each do |k, v|
        ch.store('ks_meta', ks_meta.strip) if ks_meta.strip.length > 0
        ch
      end

      def aliased(k)
        # converting 'foo-bar' keys into 'foo_bar' keys
        k1 = k.gsub(/-/,'_')
        # converting orig keys into alias keys
        # example: 'ksmeta' into 'ks_meta'
        k2 = ALIASES.each_key.select{|ak| ALIASES[ak].include?(k1)}[0] || k1
        Astute.logger.debug("Key #{k} aliased with #{k2}") if k != k2
        k2
      end

      def valid_field?(k)
        (FIELDS[fetch('what')]['fields'].include?(k) or
          (FIELDS[fetch('what')]['special'] or []).include?(k))
      end

      def valid_interface_field?(k)
        (FIELDS[fetch('what')]['interfaces_fields'] or []).include?(k)
      end

      def cobblerized_interfaces
        interfaces = {}
        fetch('interfaces').each do |iname, ihash|
          ihash.each do |iopt, ivalue|
            iopt = aliased(iopt)
            if interfaces.has_key?("#{iopt}-#{iname}")
              raise CobblerError, "Wrong interface cobbler data: #{iopt} is duplicated"
            end
            unless valid_interface_field?(iopt)
              Astute.logger.debug("Interface key #{iopt} is not valid. Skipping")
              next
            end
            Astute.logger.debug("Defining interfaces[#{iopt}-#{iname}] = #{ivalue}")
            interfaces["#{iopt}-#{iname}"] = ivalue
          end
        end
        interfaces
      end

      def cobblerized_interfaces_extra
        # here we just want to convert interfaces_extra into ks_meta
        interfaces_extra_str = ""
        fetch('interfaces_extra').each do |iname, iextra|
          iextra.each do |k, v|
            Astute.logger.debug("Adding into ks_meta interface_extra_#{iname}_#{k}=#{v}")
            interfaces_extra_str << " interface_extra_#{iname}_#{k}=#{v}"
          end
        end
        interfaces_extra_str
      end
    end

  end
end
