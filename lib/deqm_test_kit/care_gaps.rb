# frozen_string_literal: true

require 'json'
require_relative '../utils/assertion_utils'

module DEQMTestKit
  # tests for $care-gaps
  # rubocop:disable Metrics/ClassLength
  class CareGaps < Inferno::TestGroup
    # module for shared code for $care-gaps assertions and requests
    module CareGapsHelpers
      def care_gaps_assert_success(params, expected_status: 200)
        fhir_operation("/Measure/$care-gaps?#{params}")
        assert_success(:parameters, expected_status)
      end

      def care_gaps_assert_failure(params, expected_status: 400)
        fhir_operation("/Measure/$care-gaps?#{params}")
        assert_error(expected_status)
      end
    end
    id 'care_gaps'
    title 'Gaps in Care'
    description 'Ensure FHIR server can calculate gaps in care for a measure'

    fhir_client do
      url :url
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options,
                        title: 'Measure ID' }

    INVALID_SUBJECT_ID = 'INVALID_SUBJECT_ID'
    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'

    test do
      include CareGapsHelpers
      title 'Check $care-gaps proper calculation with required query parameters for Patient subject'
      id 'care-gaps-01'
      description %(Server should properly return a care gaps report
    when the required query parameters \(periodStart, periodEnd, status\) are provided
      and subject is a Patient resource.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
                 "&subject=Patient/#{patient_id}&status=open-gap"
        care_gaps_assert_success(params)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps proper calculation with required query parameters for Group subject'
      id 'care-gaps-02'
      description %(Server should properly return a care gaps report
    when the required query parameters \(periodStart, periodEnd, status\) are provided
      and subject is a Group resource.)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'
      input :group_id, title: 'Group ID'

      run do
        params = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
                 "&subject=Group/#{group_id}&status=open-gap"
        care_gaps_assert_success(params)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps returns a BadRequest error for missing required query parameter'
      id 'care-gaps-03'
      description %(Server should not perform calculation and return a 400 response code
    when one of the required query parameters is omitted from the request. In this test,
      the measurement period start is omitted from the request.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        invalid_params = "measureId=#{measure_id}&periodEnd=#{period_end}&subject=Patient/#{patient_id}&status=open-gap"
        care_gaps_assert_failure(invalid_params)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps returns a BadRequest error for subject and organization query parameters'
      id 'care-gaps-04'
      description %(Server should not perform calculation and return a 400 response code
    when both the subject and organization query parameters are provided in the request.
      As stated in the $care-gaps FHIR spec, these query parameters are mutually
      exclusive.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        # A request with invalid practitioner and organization ids
        invalid_optional = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
                           "&subject=Patient/#{patient_id}&status=open-gap&organization=Organization/testOrganization"
        care_gaps_assert_failure(invalid_optional)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps returns a BadRequest error for invalid subject format'
      id 'care-gaps-05'
      description "Server should not perform calculation and return a 400 response code
    when both the subject query parameter is not of the form Patient/<id> or Group/<id>."
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        # Parameters with an invalid patient id for subject
        invalid_subject = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
                          "&status=open-gap&subject=#{INVALID_SUBJECT_ID}"
        care_gaps_assert_failure(invalid_subject)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps proper calculation when no measure identifier is provided'
      id 'care-gaps-06'
      description %(Server should properly return a care gaps report
    when the required query parameters \(periodStart, periodEnd, status\) are provided,
      subject is a Patient resource, and no measure identifier has been provided.)
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}&status=open-gap"
        care_gaps_assert_success(params)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps returns NotFound error when invalid measure identifier is provided'
      id 'care-gaps-07'
      description %(Server should not perform calculation and return a 404 response code
    when the provided measure identifier cannot be found on the server)
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "measureId=#{INVALID_MEASURE_ID}&periodStart=#{period_start}&periodEnd=#{period_end}" \
                 "&subject=Patient/#{patient_id}&status=open-gap"
        care_gaps_assert_failure(params, expected_status: 404)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps proper calculation with practitioner and organization query parameters'
      id 'care-gaps-08'
      description %(Server should properly return a care gaps report
    when the required query parameters \(periodStart, periodEnd, status\) are provided and
      an organization and practitioner are provided rather than a Patient/Group subject.)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'
      input :practitioner_id, title: 'Practitioner ID'
      input :org_id, title: 'Organization ID'

      run do
        params = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
                 "&status=open-gap&practitioner=Practitioner/#{practitioner_id}&organization=Organization/#{org_id}"
        care_gaps_assert_success(params)
      end
    end
    test do
      include CareGapsHelpers
      title 'Check $care-gaps proper calculation with program query parameter'
      id 'care-gaps-09'
      description %(Server should properly return a care gaps report
    when the required query parameters \(periodStart, periodEnd, status\) are provided and
      a program query parameter is provided.)
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}" \
                 "&subject=Patient/#{patient_id}&status=open-gap&program=eligible-provider"
        care_gaps_assert_success(params)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
