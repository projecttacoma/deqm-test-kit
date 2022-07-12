# DEQM Test Kit

This repository is an [Inferno](https://github.com/inferno-community/inferno-core) test kit
for testing conformance to the operations and resources specified in the 
[Data Exchange for Quality Measures (DEQM) Implementation Guide](http://hl7.org/fhir/us/davinci-deqm/).

## Instructions

- Clone this repo.
- Write your tests in the `lib` folder.
- Put additional `package.tgz`s for the IGs you're writing tests for in
  `lib/deqm_test_kit/igs` and update this path in `docker-compose.yml`.
  This will ensure that the validator has access to the resources needed to
  validate resources against your IGs.
- Run setup.sh in this repo to pull the needed docker images and set up the database.
- Run `docker-compose up` in this repo.
- Navigate to `http://localhost:4567`. Your test suite will be available.

## Distributing tests

In order to make your test suite available to others, it needs to be organized
like a standard ruby gem (ruby libraries are called gems).

- Your tests must be in `lib`
- `lib` should contain only one file. All other files should be in a
  subdirectory. The file in lib be what people use to import your gem after they
  have installed it. For example, if your test kit contains a file
  `lib/my_test_suite.rb`, then after installing your test kit gem, I could
  include your test suite with `require 'my_test_suite'`.
- **Optional:** Once your gemspec file has been updated, you can publish your
  gem on [rubygems, the official ruby gem repository](https://rubygems.org/). If
  you don't publish your gem on rubygems, users will still be able to install it
  if it is located in a public git repository. To publish your gem on rubygems,
  you will first need to [make an account on
  rubygems](https://guides.rubygems.org/publishing/#publishing-to-rubygemsorg)
  and then run `gem build *.gemspec` and `gem push *.gem`.

## Example Inferno test kits

- https://github.com/inferno-community/ips-test-kit
- https://github.com/inferno-community/shc-vaccination-test-kit
