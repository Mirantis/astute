metadata    :name        => "puppetd",
            :description => "Run puppet agent, get its status, and enable/disable it",
            :author      => "R.I.Pienaar",
            :license     => "Apache License 2.0",
            :version     => "1.8",
            :url         => "https://github.com/puppetlabs/mcollective-plugins",
            :timeout     => 40

action "last_run_summary", :description => "Get a summary of the last puppet run" do
    display :always

    output :time,
           :description => "Time per resource type",
           :display_as => "Times"
    output :resources,
           :description => "Overall resource counts",
           :display_as => "Resources"

    output :changes,
           :description => "Number of changes",
           :display_as => "Changes"

    output :events,
           :description => "Number of events",
           :display_as => "Events"

    output :version,
           :description => "Puppet and Catalog versions",
           :display_as => "Versions"
end

action "enable", :description => "Enable puppet agent" do
    output :output,
           :description => "String indicating status",
           :display_as => "Status"
end

action "disable", :description => "Disable puppet agent" do
    output :output,
           :description => "String indicating status",
           :display_as => "Status"
end

action "runonce", :description => "Invoke a single puppet run" do
    #input :forcerun,
    #    :prompt      => "Force puppet run",
    #    :description => "Should the puppet run happen immediately?",
    #    :type        => :string,
    #    :validation  => '^.+$',
    #    :optional    => true,
    #    :maxlength   => 5

    output :output,
           :description => "Output from puppet agent",
           :display_as => "Output"
end

action "status", :description => "Get puppet agent's status" do
    display :always

    output :status,
           :description => "The status of the puppet agent: disabled, running, idling or stopped",
           :display_as => "Status"

    output :enabled,
           :description => "Whether puppet agent is enabled",
           :display_as => "Enabled"

    output :running,
           :description => "Whether puppet agent is running",
           :display_as => "Running"

    output :idling,
           :description => "Whether puppet agent is idling",
           :display_as => "Idling"

    output :stopped,
           :description => "Whether puppet agent is stopped",
           :display_as => "Stopped"

    output :lastrun,
           :description => "When puppet agent last ran",
           :display_as => "Last Run"

    output :output,
           :description => "String displaying agent status",
           :display_as => "Status"
end

action "apply", :description => "Run Puppet apply with custom site.pp" do
    display :always

    input :modulepath,
          :prompt         => 'modulepath',
          :description    => 'Path to directory where puppet modules are',
          :type           => :string,
          :validation     => '.*',
          :maxlength      => 0,
          :optional       => false

    input :sitepp_content,
          :prompt         => 'sitepp_content',
          :description    => 'Content of site.pp',
          :type           => :string,
          :validation     => '.*',
          :maxlength      => 0,
          :optional       => false

    output  :sitepp,
            :description  => "Name of temporary file with site.pp content",
            :display_as   => "Site.pp filename"

    output  :puppet_pid,
            :description  => 'PID of Puppet apply instance',
            :display_as   => 'Puppet PID'
end

action "apply_status", :description => 'Return status of Puppet apply by PID' do
    display :always

    input :puppet_pid,
          :prompt         => 'puppet_pid',
          :description    => 'PID of running Puppet apply',
          :type           => :integer,
          :optional       => false

    output :status,
           :description => "The status of the puppet apply: running or stopped",
           :display_as => "Status"

    output :running,
           :description => "Whether puppet apply is running",
           :display_as => "Running"

    output :stopped,
           :description => "Whether puppet apply is stopped",
           :display_as => "Stopped"

    output :lastrun,
           :description => "When puppet apply last ran",
           :display_as => "Last Run"
end
