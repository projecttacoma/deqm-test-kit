# frozen_string_literal: true

require_relative '../../utils/collect_data_spec_utils'

INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
INVALID_START_DATE = 'INVALID_START_DATE'

RSpec.describe DEQMTestKit::CollectDataV1 do
  include DEQMTestKit::CollectDataSpecUtils

  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v100') }
  let(:group) { suite.groups[2] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  describe 'GET Measure/$collect-data with one measureUrl and required params' do
    let(:test) { test_by_id(group, 'collect-data-one-measure-get') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureUrl: measure_url,
          periodStart: period_start,
          periodEnd: period_end
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with one measureUrl and required params' do
    let(:test) { test_by_id(group, 'collect-data-one-measure-post') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(measure_urls: [measure_url], period_start:, period_end:)
      parameters_response = create_parameters_response(measure_urls: [measure_url])

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

      result = run(test, url:, measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data with two measureUrls and required params' do
    let(:test) { test_by_id(group, 'collect-data-two-measure-get') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url, additional_measure_url])
      query = URI.encode_www_form([
                                    ['measureUrl', measure_url],
                                    ['measureUrl', additional_measure_url],
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

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with two measureUrls and required params' do
    let(:test) { test_by_id(group, 'collect-data-two-measure-post') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url, additional_measure_url])
      parameters_request = create_parameters_request(
        measure_urls: [measure_url, additional_measure_url],
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

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data with one measureUrl and subject=Patient/patientId' do
    let(:test) { test_by_id(group, 'collect-data-one-measure-get-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureUrl: measure_url,
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

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with one measureUrl and subject=Patient/patientId' do
    let(:test) { test_by_id(group, 'collect-data-one-measure-post-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(measure_urls: [measure_url], period_start:, period_end:,
                                                     patient_id:)
      parameters_response = create_parameters_response(measure_urls: [measure_url])

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

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data with two measureUrls and subject=Patient/patientId' do
    let(:test) { test_by_id(group, 'collect-data-two-measure-get-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url, additional_measure_url])
      query = URI.encode_www_form([
                                    ['measureUrl', measure_url],
                                    ['measureUrl', additional_measure_url],
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

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with two measureUrls and subject=Patient/patientId' do
    let(:test) { test_by_id(group, 'collect-data-two-measure-post-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(measure_urls: [measure_url, additional_measure_url], period_start:,
                                                     period_end:, patient_id:)
      parameters_response = create_parameters_response(measure_urls: [measure_url, additional_measure_url])

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

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with one measureUrl and subjectGroup' do
    let(:test) { test_by_id(group, 'collect-data-one-measure-post-subject-group') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1, patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(
        measure_urls: [measure_url], patient_ids: patient_id_list
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

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end

    it 'fails if result has incorrect number of measure reports' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id_list:
      )
      parameters_response = FHIR::Parameters.new(
        parameter: patient_id_list.map do
          FHIR::Parameters::Parameter.new(
            name: 'return',
            resource: FHIR::Bundle.new(
              type: 'transaction',
              entry: [] # no measure reports
            )
          )
        end
      )

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

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end

    it 'fails if result has incorrect number of bundles' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url])

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

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'POST Measure/$collect-data with two measureUrls and subjectGroup' do
    let(:test) { test_by_id(group, 'collect-data-two-measures-post-subject-group') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1,patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls:, patient_ids: patient_id_list)

      stub_request(:post, "#{url}/Measure/$collect-data").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end

    it 'fails if result has incorrect number of measure reports' do
      measure_urls = [measure_url, additional_measure_url]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = FHIR::Parameters.new(
        parameter: patient_id_list.map do
          FHIR::Parameters::Parameter.new(
            name: 'return',
            resource: FHIR::Bundle.new(
              type: 'transaction',
              entry: [
                {
                  resource: FHIR::MeasureReport.new(
                    status: 'complete',
                    type: 'data-collection',
                    measure: measure_url,
                    period: { start: period_start, end: period_end }
                  )
                }
              ]
            )
          )
        end
      )

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

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end

    it 'fails if result has incorrect number of bundles' do
      measure_urls = [measure_url, additional_measure_url]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls:)

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

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'GET Measure/$collect-data missing periodEnd' do
    let(:test) { test_by_id(group, 'collect-data-missing-period-end-get-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureUrl: measure_url,
          periodStart: period_start
          # periodEnd intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data missing periodEnd' do
    let(:test) { test_by_id(group, 'collect-data-missing-period-end-post-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'measureUrl', valueCanonical: measure_url },
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

      result = run(test, url:, measure_url:, period_start:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data missing periodStart' do
    let(:test) { test_by_id(group, 'collect-data-missing-period-start-get-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$collect-data"
      ).with(
        query: {
          measureUrl: measure_url,
          periodEnd: period_end
          # periodStart intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data missing periodStart' do
    let(:test) { test_by_id(group, 'collect-data-missing-period-start-post-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'measureUrl', valueCanonical: measure_url },
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

      result = run(test, url:, measure_url:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$collect-data missing measureUrl' do
    let(:test) { test_by_id(group, 'collect-data-missing-measure-url-get-fail') }
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
          # measureUrl intentionally omitted
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

  describe 'POST Measure/$collect-data missing measureUrl' do
    let(:test) { test_by_id(group, 'collect-data-missing-measure-url-post-fail') }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'periodStart', valueDate: period_start },
          { name: 'periodEnd', valueDate: period_end }
          # measureUrl intentionally omitted
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
