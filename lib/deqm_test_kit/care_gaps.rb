# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $care-gaps
  # rubocop:disable Metrics/ClassLength
  class CareGaps < Inferno::TestGroup
    id 'care_gaps'
    title 'Gaps in Care'
    description 'Ensure FHIR server can calculate gaps in care for a measure'

    fhir_client do
      url :url
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = {type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options}

    INVALID_ID = 'INVALID_ID'

    test do
      title 'Check $care-gaps proper calculation'
      id 'care-gaps-01'
      description 'Server should properly return a gaps report'
      input :measure_id, measure_id_args
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}"\
                 "&subject=#{patient_id}&status=open-gap"
        fhir_operation("/Measure/$care-gaps?#{params}")

        assert_response_status(200)
        assert_resource_type(:parameters)
        assert_valid_json(response[:body])
      end
    end
    test do
      title 'Check $care-gaps missing required parameter'
      id 'care-gaps-02'
      description 'Server should return a 400 response code'
      input :measure_id, measure_id_args
      input :patient_id
      input :period_end, default: '2019-12-31'

      run do
        invalid_params = "measureId=#{measure_id}&periodEnd=#{period_end}&subject=#{patient_id}&status=open-gap"
        fhir_operation("/Measure/$care-gaps?#{invalid_params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
    test do
      title 'Check $care-gaps with invalid optional parameters'
      id 'care-gaps-03'
      description 'Server should return a 501 response code'
      input :measure_id, measure_id_args
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        # A request with invalid practitioner and organization ids
        invalid_optional = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}"\
                           "&subject=#{patient_id}&status=open-gap&practitioner=INVALID&organization=INVALID"
        fhir_operation("/Measure/$care-gaps?#{invalid_optional}")

        assert_response_status(501)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
    test do
      title 'Check $care-gaps with invalid subject'
      id 'care-gaps-04'
      description 'Server should return a 400 response code'
      input :measure_id, measure_id_args
      input :measure_id, :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        # Parameters with an invalid patient id for subject
        invalid_subject = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}"\
                          '&status=open-gap&subject=INVALID'
        fhir_operation("/Measure/$care-gaps?#{invalid_subject}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
    test do
      title 'Check $care-gaps with no measure identifier'
      id 'care-gaps-05'
      description 'Server should return a 200 response code'
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}&status=open-gap"
        fhir_operation("/Measure/$care-gaps?#{params}")

        assert_response_status(200)
        assert_resource_type(:parameters)
        assert_valid_json(response[:body])
      end
    end
    test do
      title 'Check $care-gaps with invalid measure id'
      id 'care-gaps-06'
      description 'Server should return a 404 response code'
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "measureId=INVALID_MEASURE&periodStart=#{period_start}&periodEnd=#{period_end}"\
                 "&subject=#{patient_id}&status=open-gap"
        fhir_operation("/Measure/$care-gaps?#{params}")

        assert_response_status(404)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
