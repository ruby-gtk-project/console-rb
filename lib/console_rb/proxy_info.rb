# frozen_string_literal: true

module ConsoleRb
  # Maps org.gnome.system.proxy onto the environment variables command-line
  # tools expect, so curl and friends inherit the desktop's proxy settings.
  # Only manual proxies are mapped, as upstream does — "automatic" means a PAC
  # script, which there is no environment variable for.
  class ProxyInfo
    SCHEMA = 'org.gnome.system.proxy'

    # child schema => [uri scheme, environment variable]
    PROTOCOLS = {
      'http' => %w[http http_proxy],
      'https' => %w[http https_proxy],
      'ftp' => %w[http ftp_proxy],
      'socks' => %w[socks all_proxy]
    }.freeze

    def environment
      manual? ? mapped_environment : {}
    rescue StandardError => e
      warn "console-rb: could not read proxy settings: #{e.message}"
      {}
    end

    def mapped_environment
      PROTOCOLS.each_with_object({}) do |(protocol, (scheme, variable)), env|
        proxy_uri(protocol, scheme)&.then { |uri| set_both(env, variable, uri) }
      end.then { |env| add_ignored(env) }
    end

    def manual? = settings.get_string('mode') == 'manual'

    def settings = @settings ||= Gio::Settings.new(SCHEMA)

    def proxy_uri(protocol, scheme)
      settings.get_child(protocol).then do |child|
        host = child.get_string('host')
        port = child.get_int('port')
        next nil if host.to_s.empty? || port.zero?

        "#{scheme}://#{credentials(protocol, child)}#{host}:#{port}/"
      end
    end

    # Only the http child carries authentication in the GNOME schema.
    def credentials(protocol, child)
      return '' unless protocol == 'http' && child.get_boolean('use-authentication')

      [child.get_string('authentication-user'),
       child.get_string('authentication-password')].then do |(user, password)|
        user.to_s.empty? ? '' : "#{escape(user)}:#{escape(password)}@"
      end
    end

    def escape(value) = URI.encode_www_form_component(value.to_s)

    def add_ignored(env)
      settings.get_strv('ignore-hosts').then do |hosts|
        set_both(env, 'no_proxy', hosts.join(',')) unless hosts.empty?
      end
      env
    end

    # Tools disagree about the case, so both spellings are set — as upstream does.
    def set_both(env, variable, value)
      env[variable] = value
      env[variable.upcase] = value
    end
  end
end
