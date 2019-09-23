# Cert Bundle Generator

This ruby script is designed to generate cert bundles for Puppet using a single Root CA and many intermediates. This would allow geographically dispersed installations to have a central Root CA and a different intermediate per region, or to use active-active certificate authorities without the need for a synced serial file. e.g.

```shell
Root CA
├── UK Intermediate CA
│    └── UK Agents
├── AUS Intermediate CA
│    └── AUS Agents
└── USA Intermediate CA
     └── USA Agents
```

First, install all dependencies:

```shell
bundle install
```

To generate a root CA bundle:

```
> bundle exec ruby gen_certs.rb
What type of CA would you like to generate? (root or intermediate)
root
Name of the Root CA:
Super Amazing Global Root CA
Expiry in years: (5)
15
CA Generated, writing to disk...
Creating: root_ca/cert.pem
Creating: root_ca/crl.pem
Creating: root_ca/private_key.pem
```

The ca bundle will always be created in a folder called `root_ca` in the current directory. *Do not move this as its hardcoded location is used for generating intermediates (yes I know...)*

To generate an intermediate:

```
> bundle exec ruby gen_certs.rb
What type of CA would you like to generate? (root or intermediate)
intermediate
Subject of this intermediate CA (Usually the FQDN of the Server):
Super Amazing Australian CA
Comma separatedDNS alternative names: ('')
puppet.aus.puppet.com,pe.aus.puppet.com
Expiry in years: (5)

Creating: Super Amazing Australian CA/ca_bundle.pem
Creating: Super Amazing Australian CA/crl_chain.pem
Creating: Super Amazing Australian CA/private_key.pem
```

Now we have all of the certs generated we can build the Australian Puppet infrastructure and make sure that it uses the correct cert by copying the bundle to the new Puppet Master and [adding the following to `pe.conf`:](https://puppet.com/docs/pe/2019.1/use_an_independent_intermediate_ca.html)

```hocon
{
 "pe_install::signing_ca": {
   "bundle": "/root/ca/ca_bundle.pem"
   "crl_chain": "/root/ca/crl_chain.pem"
   "private_key": "/root/ca/private_key.pem"
 }
}
```

After this run the installer and the new Puppet master should sign certs under the new intermediate

## Possible Expansion

* Add arguments as well as the "Wizard"
* Add the ability to have intermediates of intermediates etc.
