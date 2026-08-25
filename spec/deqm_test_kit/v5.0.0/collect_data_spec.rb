# frozen_string_literal: true

require_relative '../../utils/collect_data_spec_utils'

INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
INVALID_START_DATE = 'INVALID_START_DATE'

RSpec.describe DEQMTestKit::CollectDataV5 do
  include DEQMTestKit::CollectDataSpecUtils

  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v500') }
  let(:collect_data_group) { suite.groups[7] }
  let(:base_tests) { collect_data_group.groups[0] }
  let(:subject_tests) { collect_data_group.groups[1] }
  let(:subject_group_tests) { collect_data_group.groups[2] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  describe 'GET Measure/$collect-data with one measureId and required params' do
    let(:test) { test_by_id(base_tests, 'collect-data-one-measure-get') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_ids: [measure_id])

      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureId: measure_id,
          periodStart: period_start,
          periodEnd: period_end
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with one measureId and required params' do
    let(:test) { test_by_id(base_tests, 'collect-data-one-measure-post') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(measure_ids: [measure_id], period_start:, period_end:)
      parameters_response = create_parameters_response(measure_ids: [measure_id])

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data with two measureIds and required params' do
    let(:test) { test_by_id(base_tests, 'collect-data-two-measure-get') }
    let(:measure_id) { 'measure-EXM130' }
    let(:additional_measures) { ['measure-EXM124'] }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_ids = [measure_id, *additional_measures]
      parameters_response = create_parameters_response(measure_ids:)
      query = URI.encode_www_form([
                                    ['measureId', measure_id],
                                    ['measureId', additional_measures],
                                    ['periodStart', period_start],
                                    ['periodEnd', period_end]
                                  ])

      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: query,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with two measureIds and required params' do
    let(:test) { test_by_id(base_tests, 'collect-data-two-measure-post') }
    let(:measure_id) { 'measure-EXM130' }
    let(:additional_measures) { ['measure-EXM124'] }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_ids = [measure_id, *additional_measures]
      parameters_response = create_parameters_response(measure_ids:)
      parameters_request = create_parameters_request(
        measure_ids:,
        period_start:,
        period_end:
      )

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data with one measureId and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'collect-data-one-measure-get-subject-patient') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_ids: [measure_id])

      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureId: measure_id,
          subject: "Patient/#{patient_id}",
          periodStart: period_start,
          periodEnd: period_end
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with one measureId and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'collect-data-one-measure-post-subject-patient') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(measure_ids: [measure_id], period_start:, period_end:,
                                                     patient_id:)
      parameters_response = create_parameters_response(measure_ids: [measure_id])

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data with two measureIds and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'collect-data-two-measure-get-subject-patient') }
    let(:measure_id) { 'measure-EXM130' }
    let(:additional_measures) { ['measure-EXM124'] }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_ids = [measure_id, *additional_measures]
      parameters_response = create_parameters_response(measure_ids:)
      query = URI.encode_www_form([
                                    ['measureId', measure_id],
                                    ['measureId', additional_measures],
                                    ['periodStart', period_start],
                                    ['periodEnd', period_end],
                                    ['subject', "Patient/#{patient_id}"]
                                  ])

      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: query,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with two measureIds and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'collect-data-two-measure-post-subject-patient') }
    let(:measure_id) { 'measure-EXM130' }
    let(:additional_measures) { ['measure-EXM124'] }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_ids = [measure_id, *additional_measures]
      parameters_request = create_parameters_request(measure_ids:, period_start:,
                                                     period_end:, patient_id:)
      parameters_response = create_parameters_response(measure_ids:)

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with one measureId and subjectGroup' do
    let(:test) { test_by_id(subject_group_tests, 'collect-data-one-measure-post-subject-group') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1, patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_ids: [measure_id], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(
        measure_ids: [measure_id], bundle_count: patient_id_list.length
      )

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end

    it 'fails if result has incorrect number of measure reports' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_ids: [measure_id], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_ids: [measure_id, measure_id],
                                                       bundle_count: patient_id_list.length)

      stub_request(
        :post, "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end

    it 'fails if result has incorrect number of bundles' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_ids: [measure_id], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_ids: [measure_id])

      stub_request(
        :post, "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'POST Measure/$collect-data with two measureIds and subjectGroup' do
    let(:test) { test_by_id(subject_group_tests, 'collect-data-two-measures-post-subject-group') }
    let(:measure_id) { 'measure-EXM130' }
    let(:additional_measures) { ['measure-EXM124'] }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1,patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_ids = [measure_id, *additional_measures]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_ids:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_ids:, bundle_count: patient_id_list.length)

      stub_request(:post, "#{url}/Measure/$collect-data").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end

    it 'fails if result has incorrect number of measure reports' do
      measure_ids = [measure_id, *additional_measures]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_ids:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_ids: [measure_id],
                                                       bundle_count: patient_id_list.length)

      stub_request(
        :post, "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end

    it 'fails if result has incorrect number of bundles' do
      measure_ids = [measure_id, *additional_measures]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_ids:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_ids:)

      stub_request(
        :post, "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'GET Measure/$collect-data missing periodEnd' do
    let(:test) { test_by_id(base_tests, 'collect-data-missing-period-end-get-fail') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_start) { '2019-01-01' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureId: measure_id,
          periodStart: period_start
          # periodEnd intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data missing periodEnd' do
    let(:test) { test_by_id(base_tests, 'collect-data-missing-period-end-post-fail') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_start) { '2019-01-01' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'measureId', valueId: measure_id },
          { name: 'periodStart', valueDate: period_start }
          # periodEnd intentionally omitted
        ]
      }

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data missing periodStart' do
    let(:test) { test_by_id(base_tests, 'collect-data-missing-period-start-get-fail') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureId: measure_id,
          periodEnd: period_end
          # periodStart intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data missing periodStart' do
    let(:test) { test_by_id(base_tests, 'collect-data-missing-period-start-post-fail') }
    let(:measure_id) { 'measure-EXM130' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'measureId', valueId: measure_id },
          { name: 'periodEnd', valueDate: period_end }
          # periodStart intentionally omitted
        ]
      }

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data missing measureId' do
    let(:test) { test_by_id(base_tests, 'collect-data-missing-measure-id-get-fail') }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          periodStart: period_start,
          periodEnd: period_end
          # measureId intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data missing measureId' do
    let(:test) { test_by_id(base_tests, 'collect-data-missing-measure-id-post-fail') }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'periodStart', valueDate: period_start },
          { name: 'periodEnd', valueDate: period_end }
          # measureId intentionally omitted
        ]
      }

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end
end
