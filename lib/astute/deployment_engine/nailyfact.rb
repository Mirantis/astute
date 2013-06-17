class Astute::DeploymentEngine::NailyFact < Astute::DeploymentEngine

  def deploy(nodes, attrs)
    attrs_for_mode = self.send("attrs_#{attrs['deployment_mode']}", nodes, attrs)
    super(nodes, attrs_for_mode)
  end

  def create_facts(node, attrs)
    # calculate_networks method is common and you can find it in superclass
    # if node['network_data'] is undefined, we use empty list because we later try to iterate over it
    #   otherwise we will get KeyError
    node_network_data = node['network_data'].nil? ? [] : node['network_data']
    interfaces = node['meta']['interfaces']
    network_data_puppet = calculate_networks(node_network_data, interfaces)
    metadata = {
      'role' => node['role'],
      'uid'  => node['uid'],
      'network_data' => network_data_puppet.to_json
    }

    attrs.each do |k, v|
      if v.is_a? String
        metadata[k] = v
      else
        # And it's the problem on the puppet side now to decode json
        metadata[k] = v.to_json
      end
    end

    # Let's calculate interface settings we need for OpenStack:
    node_network_data.each do |iface|
      device = if iface['vlan'] && iface['vlan'] > 0
        [iface['dev'], iface['vlan']].join('.')
      else
        iface['dev']
      end
      metadata["#{iface['name']}_interface"] = device
      if iface['ip']
        metadata["#{iface['name']}_address"] = iface['ip'].split('/')[0]
      end
    end

    # internal_address is required for HA..
    metadata['internal_address'] = node['network_data'].select{|nd| nd['name'] == 'management' }[0]['ip'].split('/')[0]

    if metadata['network_manager'] == 'VlanManager' && !metadata['fixed_interface']
      metadata['fixed_interface'] = get_fixed_interface(node)
    end

    Astute::Metadata.publish_facts(@ctx, node['uid'], metadata, 'fake' => fake)
  end

  def deploy_piece(nodes, attrs, retries=2, change_node_status=true)
    return false unless validate_nodes(nodes)
    @ctx.reporter.report nodes_status(nodes, 'deploying', {'progress' => 0})

    Astute.logger.info "#{@ctx.task_id}: Calculation of required attributes to pass, include netw.settings"
    nodes.each do |node|
      create_facts(node, attrs)
    end
    return if fake
    Astute.logger.info "#{@ctx.task_id}: All required attrs/metadata passed via facts extension. Starting deployment."

    Astute::PuppetdDeployer.deploy(@ctx, nodes, retries, change_node_status)
    nodes_roles = nodes.map { |n| { n['uid'] => n['role'] } }
    Astute.logger.info "#{@ctx.task_id}: Finished deployment of nodes => roles: #{nodes_roles.inspect}"
  end

  private
  def get_fixed_interface(node)
    return node['vlan_interface'] if node['vlan_interface']

    Astute.logger.warn "Can not find vlan_interface for node #{node['uid']}"
    nil
  end

end
