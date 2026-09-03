# frozen_string_literal: true

# Load only the reusable SMART STU2 groups needed by DEQM. Requiring the
# test-kit entrypoint also loads unrelated SMART suites, including one that
# initializes a FHIR resource validator during local Puma startup.
require 'smart_app_launch/smart_stu2_suite'

require_relative 'deqm_test_kit/v3.0.0/deqm_test_suite'
require_relative 'deqm_test_kit/v5.0.0/deqm_test_suite'
require_relative 'deqm_test_kit/v1.0.0/deqm_test_suite'
