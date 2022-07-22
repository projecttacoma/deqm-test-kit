# DEQM Test Kit

This repository is an [Inferno](https://github.com/inferno-community/inferno-core) test kit
for testing conformance to the operations and resources specified in the 
[Data Exchange for Quality Measures (DEQM) Implementation Guide](http://hl7.org/fhir/us/davinci-deqm/).

## First Time Setup

Run the `./setup.sh` script provided in this repository. This will pull all the necessary Docker images and
run the first time database setup.

## Usage

### Docker (recommended)

`docker-compose.yml` is configured with many services that make using `deqm-test-kit` quick and easy. Running with Docker will
spin up the test kit as well as an instance of [deqm-test-server](https://github.com/projecttacoma/deqm-test-server/) for ease of testing it:

``` bash
docker-compose pull
docker-compose up --build # --build is required to get any source code changes from the lib/ directory
```

Navigate to http://localhost:4567 to run the tests in the Inferno web page

### Local Usage

The test kit can also be run locally without Docker. This is useful particularly for debugging purposes.
Make sure you have Ruby `>=2.7.0` installed.

1. Install required dependencies:

``` bash
bundle install
```

2. Run the database setup locally to configure the database:

``` bash
bundle exec inferno migrate
```

3. Run the test kit locally with `puma`:

``` bash
ASYNC_JOBS=false bundle exec puma
```

Navigate to http://localhost:4567 to run the tests in the Inferno web page

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

