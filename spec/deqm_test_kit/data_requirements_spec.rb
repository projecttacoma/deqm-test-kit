# frozen_string_literal: true

RSpec.describe DEQMTestKit::DataRequirements do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
  let(:group) { suite.groups[2] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'deqm_test_suite') }
  url = 'http://example.com/fhir'
  # ensure this url matches url in embedded_client in data_requirements.rb
  let(:embedded_client) do
    'http://cqf_ruler:8080/cqf-ruler-r4/fhir'
  end
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name: name, value: value)
    end
    Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
  end

  describe 'data requirements test' do
    let(:test) { group.tests.first }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'passes if the expected Library was received' do
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      test_library_response = FHIR::Library.new(dataRequirement: [{ type: 'Condition' }])
      test_measure = FHIR::Measure.new(id: measure_id, name: measure_name, version: measure_version)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{embedded_client}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{embedded_client}/Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 200, body: test_library_response.to_json)

      # TODO: pass in measure information once it is a measure_availability group input (and in below runs)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('pass')
    end

    it 'passes for expected Library with a valueSet codefilter' do
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      code_filters = [{ valueSet: 'testValueSet' }]
      test_library_response = FHIR::Library.new(dataRequirement: [{ type: 'Condition' }], codeFilter: code_filters)
      test_measure = FHIR::Measure.new(id: measure_id, name: measure_name, version: measure_version)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{embedded_client}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:post, "#{embedded_client}/Measure/#{measure_id}/$data-requirements")
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$data-requirements")
        .to_return(status: 200, body: test_library_response.to_json)

      # TODO: pass in measure information once it is a measure_availability group input (and in below runs)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('pass')
    end

    it 'passes for expected library with a single code codeFilter' do
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      code_filters = [{ code: [{ code: 'testcode', system: 'testsystem' }] }]
      test_library_response = FHIR::Library.new(dataRequirement: [{ type: 'Condition', codeFilter: code_filters }])
      test_measure = FHIR::Measure.new(id: measure_id, name: measure_name, version: measure_version)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{embedded_client}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:post, "#{embedded_client}/Measure/#{measure_id}/$data-requirements")
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$data-requirements")
        .to_return(status: 200, body: test_library_response.to_json)

      # TODO: pass in measure information once it is a measure_availability group input (and in below runs)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('pass')
    end

    it 'fails if a 200 is not received' do
      # external client returns 201 instead of 200

      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])
      test_library_response = FHIR::Library.new(dataRequirement: [{ type: 'Condition' }])
      test_measure = FHIR::Measure.new(id: measure_id)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{embedded_client}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{embedded_client}/Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 200, body: test_library_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 201, body: test_library_response.to_json)

      result = run(test, url: url, measure_id: measure_id)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if a Library is not received' do
      # returns a bundle not a library
      test_measure_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: measure_id } }])

      test_not_library_response = FHIR::Bundle.new
      test_measure = FHIR::Measure.new(id: measure_id)

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(:get, "#{embedded_client}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: test_measure_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 200, body: test_not_library_response.to_json)

      stub_request(
        :post,
        "#{embedded_client}/Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 200, body: test_not_library_response.to_json)

      result = run(test, url: url, measure_id: measure_id)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Bad resource type received: expected Library, but received Bundle')
    end
  end
end
