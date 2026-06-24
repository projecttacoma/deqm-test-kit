# frozen_string_literal: true

INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
INVALID_START_DATE = 'INVALID_START_DATE'

RSpec.describe DEQMTestKit::CollectDataV1 do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v100') }
  let(:group) { suite.groups[1] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  # Helper method to create a valid Parameters resource
  def create_parameters_response(measure_urls:) # rubocop:disable Metrics/MethodLength
    measure_reports = measure_urls.map do |url|
      FHIR::MeasureReport.new(
        status: 'complete', type: 'data-collection',
        measure: url,
        period: { start: '2019-01-01', end: '2019-12-31' }
      )
    end

    bundles = measure_reports.map do |mr|
      FHIR::Bundle.new(type: 'transaction', entry: [{ resource: mr }])
    end

    FHIR::Parameters.new(parameter: bundles.map do |bundle|
      {
        name: 'return',
        resource: bundle
      }
    end)
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

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
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"measureUrl","valueCanonical":"http://example.com/Measure/measure-EXM130"},{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
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

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"measureUrl","valueCanonical":"http://example.com/Measure/measure-EXM130"},{"name":"measureUrl","valueCanonical":"http://example.com/Measure/measure-EXM124"},{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
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
end
