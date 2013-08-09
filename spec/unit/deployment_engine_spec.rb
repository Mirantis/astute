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


require File.join(File.dirname(__FILE__), '../spec_helper')

describe Astute::DeploymentEngine do
  include SpecHelpers

  class Engine < Astute::DeploymentEngine; end

  let(:ctx) { mock_ctx }
  let(:deployer) { Engine.new(ctx) }

  describe '#attrs_ha' do

    def only_controllers(nodes)
      nodes.select { |node| node['role'] == 'controller' }
    end

    it 'should set last_controller' do
      attrs = deployer.attrs_ha(Fixtures.ha_nodes, {})
      attrs['last_controller'].should == only_controllers(Fixtures.ha_nodes).last['fqdn'].split(/\./)[0]
    end

    it 'should assign primary-controller role for first node if primary-controller not set directly' do
      attrs = deployer.attrs_ha(Fixtures.ha_nodes, {})
      primary = attrs['nodes'].find { |node| node['role'] == 'primary-controller' }
      primary.should_not be_nil
      primary['fqdn'].should == only_controllers(Fixtures.ha_nodes).first['fqdn']
    end

    it 'should not assign primary-controller role for first node if primary-controller set directly' do
      nodes = Fixtures.ha_nodes
      last_node = only_controllers(nodes).last
      last_node['role'] = 'primary-controller'
      attrs = deployer.attrs_ha(deep_copy(nodes), {})

      primary = attrs['nodes'].select { |node| node['role'] == 'primary-controller' }
      primary.length.should == 1
      primary[0]['fqdn'].should == last_node['fqdn']
    end

  end
end
