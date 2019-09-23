require 'puppetserver/ca/config/puppet'
require 'puppetserver/ca/errors'
require 'puppetserver/ca/local_certificate_authority'
require 'puppetserver/ca/utils/cli_parsing'
require 'puppetserver/ca/utils/file_system'
require 'puppetserver/ca/utils/signing_digest'
require 'fileutils'
require 'pry'

SECONDS_IN_YEAR = (365 * 24 * 60 * 60)

def ask(question, default = nil)
  puts question
  answer = gets.chomp
  answer.empty? ? default : answer
end

base_settings = {
  cacert: 'root_ca/cert.pem',
  cakey: 'root_ca/private_key.pem',
  cacrl: 'root_ca/crl.pem',
  keylength: 4096,
}

# Just do a wizard thing here
type = ask('What type of CA would you like to generate? (root or intermediate)')

case type
when 'root'
  settings_overrides = {}
  settings_overrides[:root_ca_name] = ask('Name of the Root CA:')
  settings_overrides[:ca_ttl] = ask('Expiry in years: (5)', 5).to_i * SECONDS_IN_YEAR

  settings = base_settings.merge(settings_overrides)

  # We are generating only a root CA
  signing_digest = Puppetserver::Ca::Utils::SigningDigest.new
  ca             = Puppetserver::Ca::LocalCertificateAuthority.new(signing_digest.digest, settings)
  root_key, root_cert, root_crl = ca.create_root_cert

  files = [
    [settings[:cacert], root_cert.to_s],
    [settings[:cacrl], root_crl.to_s],
    [settings[:cakey], root_key.to_s],
  ]

  puts "CA Generated, writing to disk..."
  FileUtils.mkdir_p 'root_ca'
when 'intermediate'
  settings_overrides = {}
  # Set the details of the new cert
  settings_overrides[:ca_name]           = ask('Subject of this intermediate CA (Usually the FQDN of the Server):')
  settings_overrides[:subject_alt_names] = ask('Comma separatedDNS alternative names: (\'\')')
  settings_overrides[:ca_ttl]            = ask('Expiry in years: (5)', 5).to_i * SECONDS_IN_YEAR

  # Set the location of the new cert
  folder = settings_overrides[:ca_name]
  settings_overrides[:hostprivkey] = "#{folder}/private_key.pem"
  settings_overrides[:hostpubkey]  = "#{folder}/public_key.pem"

  settings = base_settings.merge(settings_overrides)

  signing_digest = Puppetserver::Ca::Utils::SigningDigest.new
  ca             = Puppetserver::Ca::LocalCertificateAuthority.new(signing_digest.digest, settings)

  # Check that the root CA actually exists
  unless ca.ssl_assets_exist?
    raise "Couldn't find root CA assets at the follwoing locations: #{base_settings[:cacert]}, #{base_settings[:cakey]}, #{base_settings[:cacrl]}"
  end

  # Actuslly generate the intermediate
  ca.create_intermediate_cert(ca.key, ca.cert)

  files = [
    ["#{folder}/ca_bundle.pem", [ca.cert.to_s, ca.cert_bundle[0].to_s].join("\n")],
    ["#{folder}/crl_chain.pem",  [ca.crl.to_s,  ca.crl_chain[0].to_s].join("\n")],
    [settings[:hostprivkey], ca.key.to_s],
  ]

  FileUtils.mkdir_p settings[:ca_name]
end

if files
  files.each do |location, content|
    puts "Creating: #{location}"
    File.write(location, content)
  end
end
