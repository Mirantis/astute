metadata :name        => "sshkey",
         :description => "SSH key management and distribution agent. It can generate new ssh keys for given user, download, upload keys and manage authorized_keys file too.",
         :author      => "Mirantis",
         :license     => "Apache",
         :version     => "1.0",
         :url         => "http://mirantis.com",
         :timeout     => 10

action "generate_key", :description => "Generate new SSH key pair for a user" do
  display :always

  input :user,
        :prompt      => "User name",
        :description => "Name of user to generate keys for",
        :type        => :string,
        :validation  => '^[a-z_][a-z0-9_]*$',
        :optional    => false,
        :maxlength   => 30

  input :overwrite,
        :prompt      => "Force overwrite",
        :description => "Overwrite already generated keys",
        :type        => :boolean,
        :optional    => false,
        :default     => false

  output :stdout,
         :description => "Stdout of generate command",
         :display_as  => "Stdout"

  output :stderr,
         :description => "Stderr of generate command",
         :display_as  => "Stderr"

  output :status,
         :description => "Command execution status",
         :display_as  => "Status"
end

action "delete_key", :description => "Delete SSH key of given user" do
  display :always

  input :user,
        :prompt      => "User name",
        :description => "Name of user to generate keys for",
        :type        => :string,
        :validation  => '^[a-z_][a-z0-9_]*$',
        :optional    => false,
        :maxlength   => 30

  output :msg,
         :description => "Report message",
         :display_as  => "Message"
end

action "download_key", :description => "Download SSH key pair of the given user" do
  display :always

  input :user,
        :prompt      => "User name",
        :description => "Name of user to generate keys for",
        :type        => :string,
        :validation  => '^[a-z_][a-z0-9_]*$',
        :optional    => false,
        :maxlength   => 30

  output :public_key,
         :description => "Public SSH key part",
         :display_as  => "Public key"

  output :private_key,
         :description => "Private SSH key part",
         :display_as  => "Private key"
end

action "upload_key", :description => "Upload new SSH key pair of the given user" do
  display :always

  input :user,
        :prompt      => "User name",
        :description => "Name of user to generate keys for",
        :type        => :string,
        :validation  => '^[a-z_][a-z0-9_]*$',
        :optional    => false,
        :maxlength   => 30

  input :public_key,
        :prompt      => "Public key",
        :description => "Public SSH key part",
        :type        => :string,
        :validation  => '^.+$',
        :optional    => false,
        :maxlength   => 0

  input :private_key,
        :prompt      => "Private key",
        :description => "Private SSH key part",
        :type        => :string,
        :validation  => '^.+$',
        :optional    => false,
        :maxlength   => 0
  input :overwrite,
        :prompt      => "Force overwrite",
        :description => "Overwrite already generated keys",
        :type        => :boolean,
        :optional    => false,
        :default     => false

  output :msg,
         :description => "Report message",
         :display_as  => "Message"
end
