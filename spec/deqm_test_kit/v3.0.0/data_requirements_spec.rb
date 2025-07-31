# frozen_string_literal: true

RSpec.describe DEQMTestKit::DataRequirements do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v300') }
  let(:group) { suite.groups[2] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:data_requirements_reference_server) { 'http://example.com/reference/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
  let(:test_library_response) { FHIR::Library.new(dataRequirement: [{ type: 'Condition' }]) }
  let(:incorrect_severity) { FHIR::OperationOutcome.new(issue: [{ severity: 'warning' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe '$data-requirements matches reference results test' do
    let(:test) { test_by_id(group, 'data-requirements-match-reference-server') }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'passes if the expected Library was received' do
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      test_measure = FHIR::Measure.new(id: measure_id, name: measure_name, version: measure_version)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .with(headers: {
                'Content-Type' => 'application/fhir+json',
                'Accept' => 'application/fhir+json',
                'Origin' => 'http://example.com/fhir',
                'Referrer' => 'http://example.com/fhir'
              })
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_id}")
        .with(headers: {
                'Content-Type' => 'application/fhir+json',
                'Accept' => 'application/fhir+json',
                'Origin' => 'http://example.com/fhir',
                'Referrer' => 'http://example.com/fhir'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get,
                   "#{data_requirements_reference_server}/Measure?name=#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json',
                'Content-Type' => 'application/fhir+json',
                'Origin' => 'http://example.com/reference/fhir',
                'Referrer' => 'http://example.com/reference/fhir'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{data_requirements_reference_server}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{}]}', headers: {
               'Content-Type' => 'application/fhir+json',
               'Accept' => 'application/fhir+json',
               'Origin' => 'http://example.com/reference/fhir',
               'Referrer' => 'http://example.com/reference/fhir'
             })
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{}]}', headers: {
               'Content-Type' => 'application/fhir+json',
               'Accept' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:,
                         measure_id:,
                         data_requirements_reference_server:)
      expect(result.result).to eq('pass')
    end

    it 'passes for expected Library with a valueSet codefilter' do
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      code_filters = [{ valueSet: 'testValueSet' }]
      test_library_response = FHIR::Library.new(dataRequirement: [{ type: 'Condition' }], codeFilter: code_filters)
      test_measure = FHIR::Measure.new(id: measure_id, name: measure_name, version: measure_version)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json',
                'Content-Type' => 'application/fhir+json',
                'Origin' => 'http://example.com/fhir',
                'Referrer' => 'http://example.com/fhir'
              })
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json',
                'Content-Type' => 'application/fhir+json',
                'Origin' => 'http://example.com/fhir',
                'Referrer' => 'http://example.com/fhir'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{data_requirements_reference_server}/Measure" \
                         "?name=#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json',
                'Content-Type' => 'application/fhir+json',
                'Origin' => 'http://example.com/reference/fhir',
                'Referrer' => 'http://example.com/reference/fhir'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{data_requirements_reference_server}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{}]}', headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/reference/fhir',
               'Referrer' => 'http://example.com/reference/fhir'
             })
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{}]}', headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:,
                         measure_id:,
                         data_requirements_reference_server:)
      expect(result.result).to eq('pass')
    end

    it 'passes for expected library with a single code codeFilter' do
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      code_filters = [{ code: [{ code: 'testcode', system: 'testsystem' }] }]
      test_library_response = FHIR::Library.new(dataRequirement: [{ type: 'Condition', codeFilter: code_filters }])
      test_measure = FHIR::Measure.new(id: measure_id, name: measure_name, version: measure_version)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json',
                'Content-Type' => 'application/fhir+json',
                'Origin' => 'http://example.com/fhir',
                'Referrer' => 'http://example.com/fhir'
              })
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json',
                'Content-Type' => 'application/fhir+json',
                'Origin' => 'http://example.com/fhir',
                'Referrer' => 'http://example.com/fhir'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{data_requirements_reference_server}/Measure" \
                         "?name=#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json',
                'Content-Type' => 'application/fhir+json',
                'Origin' => 'http://example.com/reference/fhir',
                'Referrer' => 'http://example.com/reference/fhir'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{data_requirements_reference_server}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{}]}', headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/reference/fhir',
               'Referrer' => 'http://example.com/reference/fhir'
             })
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{}]}', headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:,
                         measure_id:,
                         data_requirements_reference_server:)
      expect(result.result).to eq('pass')
    end

    it 'fails if a 200 is not received' do
      # external client returns 201 instead of 200

      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      test_library_response = FHIR::Library.new(dataRequirement: [{ type: 'Condition' }])
      test_measure = FHIR::Measure.new(id: measure_id)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json'
              })
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .with(headers: {
                'Accept' => 'application/fhir+json'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{data_requirements_reference_server}/Measure" \
                         "?name=#{measure_name}&version=#{measure_version}")
        .with(headers: {
                'Accept' => 'application/fhir+json'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{data_requirements_reference_server}/Measure/#{measure_id}/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 201, body: test_library_response.to_json)

      result = run(test, url:,
                         measure_id:,
                         data_requirements_reference_server:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if a Library is not received' do
      # returns a bundle not a library
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])

      test_not_library_response = FHIR::Bundle.new
      test_measure = FHIR::Measure.new(id: measure_id)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .with(headers: {
                'Accept' => 'application/fhir+json'
              })
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .with(headers: {
                'Accept' => 'application/fhir+json'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{data_requirements_reference_server}/Measure" \
                         "?name=#{measure_name}&version=#{measure_version}")
        .with(headers: {
                'Accept' => 'application/fhir+json'
              })
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 200, body: test_not_library_response.to_json)

      stub_request(
        :post,
        "#{data_requirements_reference_server}/Measure/#{measure_id}/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 200, body: test_not_library_response.to_json)

      result = run(test, url:,
                         measure_id:,
                         data_requirements_reference_server:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Unexpected resource type: expected Library, but received Bundle')
    end
  end

  describe '$data-requirements with period start and period end' do
    let(:test) { test_by_id(group, 'data-requirements-with-period-parameters') }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with 200 returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=#{period_end}&periodStart=#{period_start}"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 200, body: test_library_response.to_json)
      result = run(test, url:, measure_id:, period_start:, period_end:)
      puts result
      expect(result.result).to eq('pass')
    end
    it 'fails if 200 not received' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=#{period_end}&periodStart=#{period_start}"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 201, body: test_library_response.to_json)
      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end
    it 'fails when resource returned is not of type Library' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=#{period_end}&periodStart=#{period_start}"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$data-requirements with invalid id' do
    let(:test) { test_by_id(group, 'data-requirements-invalid-measure-returns-404') }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url:, measure_id:)
      expect(result.result).to eq('pass')
    end

    it 'fails when 400 is not returned' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:)
      expect(result.result).to eq('fail')
    end

    it 'fails when returned resource type is not of type OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 404, body: test_library_response.to_json)
      result = run(test, url:, measure_id:)
      expect(result.result).to eq('fail')
    end

    it 'fails when severity returned is not equal to error' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements"
      ).with(headers: {
               'Accept' => 'application/fhir+json'
             })
        .to_return(status: 404, body: incorrect_severity.to_json)
      result = run(test, url:, measure_id:)
      expect(result.result).to eq('fail')
    end
  end
end
