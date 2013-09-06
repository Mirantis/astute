# This agent manages ssh keys and
# authorized_keys files for different users
#
# Examples:
# # get help for this agent
# $ mco plugin doc sshkey
#
# # generate new ssh key for user apache
# # and overwrite existing if present
# $ mco rpc sshkey generate_key user=apache overwrite=true
# # download generated key
# $ mco rpc sshkey download_key user=apache
# # delete ssh key
# $ mco rpc sshkey delete_key user=apache
# # upload precreated ssh key
# # overwrite old if present
# $ mco rpc sshkey upload_key user=apache private_key='(...)' public_key='(...)' overwrite=true
#
# # upload authorized_keys file
# # overwrite old if present
# $ mco rpc sshkey upload_access user=apache authorized_kyes='(...)' overwrite=true
# # download authorized_keys file
# $ mco rpc sshkey download_access user=apache
# # delete authorized_keys file
# $ mco rpc sshkey delete_access user=apache

require 'etc'
require 'fileutils'

module MCollective
  module Agent
    class Sshkey<RPC::Agent

      def fix_ssh_permissions
        if File.exist? ssh_dir 
          File.chmod 0700, ssh_dir
          File.chown uid, gid, ssh_dir
        end
        if File.exist? private_key_file
          File.chmod 0600, private_key_file
          File.chown uid, gid, private_key_file
        end
        if File.exist? public_key_file
          File.chmod 0644, public_key_file
          File.chown uid, gid, public_key_file
        end
        if File.exist? authorized_keys_file
          File.chmod 0600, authorized_keys_file
          File.chown uid, gid, authorized_keys_file
        end
      end

      def key_name
        'id_rsa'
      end

      def key_length
        2048
      end

      def user
        return @user if @user
        validate :user, :shellsafe
        @user = request.data[:user]
      end

      def home_dir
        return @user_pwd.dir if @user_pwd
        @user_pwd = Etc.getpwnam(user)
        @user_pwd.dir
      end

      def uid
        return @user_pwd.uid if @user_pwd
        @user_pwd = Etc.getpwnam(user)
        @user_pwd.uid
      end

      def gid
        return @user_pwd.gid if @user_pwd
        @user_pwd = Etc.getpwnam(user)
        @user_pwd.gid
      end

      def ssh_dir
        return @ssh_dir if @ssh_dir
        @ssh_dir = "#{home_dir}/.ssh"
      end

      def private_key_file
        return @private_key_file if @private_key_file
        @private_key_file = "#{home_dir}/.ssh/#{key_name}"
      end

      def public_key_file
        return @public_key_file if @public_key_file
        @public_key_file = private_key_file + ".pub"
      end

      def authorized_keys_file
        return @authorized_keys_file if @authorized_keys_file
        @authorized_keys_file = "#{home_dir}/.ssh/authorized_keys"
      end

      def check_ssh_dir
        Dir.mkdir ssh_dir unless File.exist? ssh_dir
      end

      def delete_key_pair_files
        File.delete private_key_file if File.exist? private_key_file
        File.delete public_key_file if File.exist? public_key_file
      end

      def delete_authorized_keys_file
        File.delete authorized_keys_file if File.exist? authorized_keys_file
      end

      action "generate_key" do
        # Generates new SSH key for the given user
        # Overwrites existing key if overwrite option is set
        # fails if key exists and option is not set

        validate :overwrite, :boolean

        begin
          # delete existing keys if overwrite is set
          # or return error if keys exist and overwrite is not set
          if File.exist? private_key_file
            if request.data[:overwrite]
              delete_key_pair_files
            else
              reply.fail! "Key #{private_key_file} already exists! Use overwrite=true to force generation."
            end
          end

          # now we can try to generate new key pair
          generate_command = "ssh-keygen -b #{key_length} -t rsa -N '' -f #{private_key_file}"
          check_ssh_dir
          reply[:status] = run(generate_command, :stdout => :stdout, :stderr => :stderr)
          # and fix generated key permissions
          fix_ssh_permissions
        rescue => e
          reply.fail! e.to_s
        end
      end
      
      action "delete_key" do
        # deletes existing public and private ssh key pair
        # does nothing if no keys are present and return message

        begin
          # report that file is not present or delete and report deletion
          if File.exist? private_key_file
            delete_key_pair_files
          else
            reply[:msg] = "Key #{private_key_file} already doesn't exist!"
            return
          end
        rescue => e
          reply.fail! e.to_s
        end
        reply[:msg] = "Key #{private_key_file} was deleted!"
      end

      action "download_key" do
        # downloads ssh key pair for given user
        # and returns them to caller
        # fails if no keys present

        begin
          # check if both keys are present
          reply.fail! "File #{private_key_file} doesn't exist!" unless File.exist? private_key_file
          reply.fail! "File #{public_key_file} doesn't exist!" unless File.exist? public_key_file

          # read both keys
          private_key = File.read private_key_file
          public_key = File.read public_key_file

          # remove newlines? no
          #private_key.gsub! /[\r\n]/, ''
          #public_key.gsub! /[\r\n]/, ''

          # and return them
          reply[:private_key] = private_key
          reply[:public_key] = public_key
        rescue => e
          reply.fail! e.to_s
        end
      end

      action "upload_key" do
        # uploads new ssh key pair for the given user
        # returns error if keys already exists and overwrite is not set
        # if overwrite is set forces upload and replaces old keys

        validate :private_key, :string
        validate :public_key, :string
        validate :overwrite, :boolean

        begin
          if File.exist? private_key_file and !request.data[:overwrite]
            reply.fail! "Key #{private_key_file} already exists! Use overwrite=true to force upload."
          end

          if File.exist? public_key_file and !request.data[:overwrite]
            reply.fail! "Key #{public_key_file} already exists! Use overwrite=true to force upload."
          end

          # check for .ssh folder, upload file and fix access and ownership
          check_ssh_dir
          File.open(private_key_file, 'w') { |file| file.write(request.data[:private_key]) }
          File.open(public_key_file, 'w') { |file| file.write(request.data[:public_key]) }
          # and fix ssh uploaded files permissions
          fix_ssh_permissions
        rescue => e
          reply.fail! e.to_s
        end
        reply[:msg] = "Key #{private_key_file} was uploaded!"
      end

      action 'distribute_keys' do
        # this action is used to distribute initially generated
        # SSH keys from master node to all managed nodes
        # these keys will later be installed into user's home
        # directories by speciall Puppet resource

        validate :private_key, :string
        validate :public_key, :string
        validate :path, :shellsafe
        validate :overwrite, :boolean

        begin
          path = request.data[:path]
          private_key_distribute = "#{path}/#{key_name}"
          public_key_distribute = "#{path}/#{key_name}.pub"

          if File.exist? private_key_distribute and !request.data[:overwrite]
            reply.fail! "Key #{private_key_distribute} already exists! Use overwrite=true to force upload."
          end

          if File.exist? public_key_distribute and !request.data[:overwrite]
            reply.fail! "Key #{public_key_distribute} already exists! Use overwrite=true to force upload."
          end

          # first create target directory on managed server
          FileUtils.mkdir_p path unless File.exist? path

          # then we can create key files and save their contents
          File.open(private_key_distribute, 'w') { |file| file.write(request.data[:private_key]) }
          File.open(public_key_distribute, 'w') { |file| file.write(request.data[:public_key]) }
        rescue => e
          reply.fail! e.to_s
        end
        reply[:msg] = "Keys was uploaded!"
      end

      action "download_access" do
        # downloads authorized_keys file for given user
        # returns error if file is not present

        begin
          # check if authorized_keys file is present
          reply.fail! "File #{authorized_keys_file} doesn't exist!" unless File.exist? authorized_keys_file
          # read the file
          authorized_keys = File.read authorized_keys_file
          # and return it as string
          reply[:authorized_keys] = authorized_keys
        rescue => e
          reply.fail! e.to_s
        end
      end

      action "upload_access" do
        # uploads new authorized_keys file for given user
        # if file is present and overwrite is not set returns error
        # forces upload if overwrite is set

        validate :authorized_keys, :string
        validate :overwrite, :boolean

        begin
          if File.exist? authorized_keys_file and !request.data[:overwrite]
            reply.fail! "Key #{authorized_keys_file} already exists! Use overwrite=true to force upload."
          end

          # check for .ssh folder, upload file and fix access and ownership
          check_ssh_dir
          File.open(authorized_keys_file, 'w') { |file| file.write(request.data[:authorized_keys]) }
          # and fix ssh uploaded file permissions
          fix_ssh_permissions
        rescue => e
          reply.fail! e.to_s
        end
        reply[:msg] = "File #{authorized_keys_file} was uploaded!"
      end

      action "delete_access" do
        # removes authorized_keys file for given user
        # to prevent key based ssh login
        # does nothing if no file present

        begin
          # report that file is not present or delete and report deletion
          if File.exist? authorized_keys_file
            delete_authorized_keys_file
          else
            reply[:msg] = "File #{authorized_keys_file} already doesn't exist!"
            return
          end
        rescue => e
          reply.fail! e.to_s
        end
        reply[:msg] = "File #{authorized_keys_file} was deleted!"
      end

    end
  end
end
