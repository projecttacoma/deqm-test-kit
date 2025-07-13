# frozen_string_literal: true

INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'
INVALID_START_DATE = 'INVALID_START_DATE'

RSpec.describe DEQMTestKit::Evaluate do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v500') }
  let(:group) { suite.groups[5] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  # Helper method to create a valid Parameters response
  def create_parameters_response(measure_report_type)
    measure_report = FHIR::MeasureReport.new(
      status: 'complete', type: measure_report_type,
      measure: 'measure-EXM130-7.3.000',
      period: { start: '2019-01-01', end: '2019-12-31' }
    )
    bundle = FHIR::Bundle.new(type: 'collection', entry: [{ resource: measure_report }])
    FHIR::Parameters.new(parameter: [{ resource: bundle }])
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe '$evaluate output matches parameter specifications' do
    let(:test) { group.tests.first }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct parameter resource returned' do
      parameters_response = create_parameters_response('individual')

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe '$evaluate output with multiple measures using Measure/$evaluate' do
    let(:test) { group.tests[1] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:additional_measures) { ['measure-EXM124-7.3.000'] }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Parameters resource containing multiple bundles' do
      # Create a Parameters response with a single bundle containing multiple entries
      measure_report_first = FHIR::MeasureReport.new(
        status: 'complete', type: 'individual',
        measure: measure_id,
        period: { start: period_start, end: period_end }
      )
      measure_report_second = FHIR::MeasureReport.new(
        status: 'complete', type: 'individual',
        measure: additional_measures.first,
        period: { start: period_start, end: period_end }
      )
      bundle = FHIR::Bundle.new(type: 'collection', entry: [
                                  { resource: measure_report_first },
                                  { resource: measure_report_second }
                                ])
      parameters_response = FHIR::Parameters.new(parameter: [
                                                   { resource: bundle }
                                                 ])

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"},{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"measureId","valueString":"measure-EXM124-7.3.000"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '257',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if one of the multiple measures is invalid' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"},{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"measureId","valueString":"INVALID_MEASURE_ID"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '253',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 404, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures: [INVALID_MEASURE_ID], patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end
  end

  describe '$evaluate successful individual report test' do
    let(:test) { group.tests[2] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" }

    it 'passes for valid individual report' do
      parameters_response = create_parameters_response('individual')

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if $evaluate does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 404, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if $evaluate does not return Parameters resource' do
      test_library = FHIR::Library.new
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: test_library.to_json, headers: {})

      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Parameters/)
    end
  end

  describe '$evaluate successful subject-list report test' do
    let(:test) { group.tests[3] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject-list" }

    it 'passes for valid subject-list report' do
      parameters_response = create_parameters_response('subject-list')

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if $evaluate does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if $evaluate does not return Parameters resource' do
      test_library = FHIR::Library.new
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: test_library.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Parameters/)
    end
  end

  describe '$evaluate successful population report test' do
    let(:test) { group.tests[4] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population" }

    it 'passes for valid population report' do
      parameters_response = create_parameters_response('summary')

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if $evaluate does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 404, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if $evaluate does not return Parameters resource' do
      test_library = FHIR::Library.new
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: test_library.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Parameters/)
    end
  end

  describe '$evaluate successful population report with Group subject test' do
    let(:test) { group.tests[5] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:group_id) { 'EXM130-patients' }
    let(:params) do
      "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population&subject=Group/#{group_id}"
    end

    it 'passes for valid Group report' do
      parameters_response = create_parameters_response('summary')

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:,
                         group_id:)
      expect(result.result).to eq('pass')
    end

    it 'fails if $evaluate does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:,
                         group_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if $evaluate does not return Parameters resource' do
      test_library = FHIR::Library.new
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
        headers: {
          'Accept' => 'application/fhir+json',
          'Accept-Charset' => 'utf-8',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Length' => '137',
          'Content-Type' => 'application/json+fhir',
          'Host' => 'example.com',
          'User-Agent' => 'Ruby FHIR Client'
        }
      )
        .to_return(status: 200, body: test_library.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:,
                         group_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Parameters/)
    end
  end

  describe '$evaluate fails for invalid measure id' do
    let(:test) { group.tests[6] }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{INVALID_MEASURE_ID}/$evaluate?#{params}"
      )
        .to_return(status: 404, body: error_outcome.to_json)

      result = run(test, url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 404 for invalid measure id' do
      stub_request(
        :post,
        "#{url}/Measure/#{INVALID_MEASURE_ID}/$evaluate?#{params}"
      )
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/404/)
    end
  end

  describe '$evaluate fails for invalid patient id' do
    let(:test) { group.tests[7] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 404, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 404 for invalid patient id' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/404/)
    end
  end

  describe '$evaluate fails for missing required params' do
    let(:test) { group.tests[8] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodEnd=#{period_end}&subject=Patient/#{patient_id}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for missing param' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/400/)
    end
  end

  describe '$evaluate fails for missing subject param for individual report type' do
    let(:test) { group.tests[9] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for missing subject param' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/400/)
    end
  end

  describe '$evaluate fails for invalid reportType' do
    let(:test) { group.tests[10] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" \
        "&reportType=#{INVALID_REPORT_TYPE}"
    end

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for invalid reportType' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/400/)
    end
  end

  # Additional tests for new functionality
  describe '$evaluate fails for invalid parameter structure' do
    let(:test) { group.tests[11] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:params) { 'periodStart2019-01-01&periodEnd=2019-12-31&subjectPatient/123' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe '$evaluate fails for missing periodEnd parameter' do
    let(:test) { group.tests[12] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:params) { "periodStart=#{period_start}&subject=Patient/#{patient_id}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:)
      expect(result.result).to eq('pass')
    end
  end
end
