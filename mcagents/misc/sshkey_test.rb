#!/usr/bin/ruby
require 'mcollective'
include MCollective::RPC

mc = rpcclient("sshkey")
mc.progress = false
mc.identity_filter 'master'

printrpc mc.generate_key(:user => 'apache', :overwrite => true)
printrpc mc.download_key(:user => 'apache')
printrpc mc.upload_key(:user => 'apache', :private_key => 'private', :public_key => 'public', :overwrite => true)
printrpc mc.download_key(:user => 'apache')
printrpc mc.delete_key(:user => 'apache')

printrpc mc.upload_access(:user => 'apache', :overwrite => true, :authorized_keys => 'test')
printrpc mc.download_access(:user => 'apache')
printrpc mc.delete_access(:user => 'apache')

mc.disconnect
