# frozen_string_literal: true

#
# Author:: Russell Seymour (<rseymour@chef.io>)
# Copyright:: 2017-2019 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# PATCHED VERSION: Fixed special character handling in passwords
# Date: December 10, 2025
# Changes: Added Base64 encoding for passwords to handle special characters

require "train-vmware/powercli"
require "base64"

module TrainPlugins
  module VMware
    # Connection class for VMware transport
    #
    # This class is responsible for connecting to the specified VIServer
    # and the SsoAdminServer
    class Connection < Train::Plugins::Transport::BaseConnection
      attr_accessor :viserver, :username, :password, :insecure
      attr_reader :powercli

      def initialize(options)
        super(options)
        @powercli = PowerCLI.new
      end

      def connect
        # Encode password to Base64 to safely handle special characters
        password_b64 = Base64.strict_encode64(options[:password].to_s)
        
        # Combine password decode and connection in single PowerShell command
        # This ensures the decoded password variable stays in scope
        login_command = "$pwd = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('#{password_b64}')); $conn = Connect-VIServer #{options[:viserver]} -User #{options[:username]} -Password $pwd; if ($conn) { Write-Output 'SUCCESS' } else { Write-Error 'FAILED' }"
        
        result = run_command_via_connection(login_command)

        # Check for explicit success marker instead of relying on exit codes
        unless result.stdout.include?("SUCCESS")
          message = "Unable to connect to VIServer at #{options[:viserver]}. "
          if result.stdout.include?("incorrect user name or password")
            message += "Please check credentials."
          else
            message += "Error: #{result.stdout}"
          end
          raise Train::UserError, message
        end

        # Connect to the SSO Admin server
        sso_command = "$pwd = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('#{password_b64}')); $conn = Connect-SsoAdminServer -Server #{options[:viserver]} -User #{options[:username]} -Password $pwd -SkipCertificateCheck; if ($conn) { Write-Output 'SUCCESS' } else { Write-Error 'FAILED' }"
        
        result = run_command_via_connection(sso_command)

        unless result.stdout.include?("SUCCESS")
          message = "Unable to connect to SsoAdminServer at #{options[:viserver]}. Error: #{result.stdout}"
          raise Train::UserError, message
        end

        @connection = self
      end

      def connection
        @connection
      end

      def platform
        direct_platform
      end

      private

      def run_command_via_connection(command)
        # Run the specified command in PowerShell
        powercli.run(command)
      end
    end
  end
end
