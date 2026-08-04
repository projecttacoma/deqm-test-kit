# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # Utility functions in support of the collect-data test groups
  module CollectDataUtils
    def selected_measure_url(custom_url:, url:, input_title: 'Measure URL',
                             custom_input_title: 'Custom Measure URL')
      return url unless url == 'Other'

      custom_url = custom_url.to_s.strip

      assert custom_url.length.positive?,
             "#{custom_input_title} is required when \"#{input_title}\" is \"Other\"."

      custom_url
    end

    def selected_additional_measure_url(custom_url:, url:)
      selected_measure_url(
        custom_url:,
        url:,
        input_title: 'Measure URL for additional Measure',
        custom_input_title: 'Custom Additional Measure URL'
      )
    end

    def selected_measure_urls
      [
        selected_measure_url(custom_url: custom_measure_url, url: measure_url),
        selected_additional_measure_url(custom_url: custom_additional_measure_url, url: additional_measure_url)
      ]
    end

    def validate_parameters_contains_bundles(parameters, measure_count)
      assert parameters.parameter.is_a?(Array), 'Expected Parameters.parameter to be an array'
      assert parameters.parameter.any?, 'Expected at least one parameter entry in Parameters resource'

      parameters.parameter.each do |param|
        assert param.resource.is_a?(FHIR::Bundle), 'Expected parameter.resource to be a Bundle'
        validate_bundles_contain_measure_report(param.resource, measure_count)
      end
    end

    def validate_number_of_bundles(parameters, bundle_count)
      assert parameters.parameter.length == bundle_count,
             "Expected #{bundle_count} Bundle(s), got #{parameters.parameter.length}"
    end

    def validate_bundles_contain_measure_report(bundle, measure_count)
      assert bundle.entry.is_a?(Array), 'Expected Bundle.entry to be an array'
      assert bundle.entry.any?, 'Expected at least one entry in the Bundle'

      measure_reports = bundle.entry.map(&:resource).grep(FHIR::MeasureReport)
      assert measure_reports.length == measure_count,
             "Expected #{measure_count} MeasureReport(s), got #{measure_reports.length}"
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def collect_data_body(options)
      parameters = options[:measure_urls].map do |url|
        {
          name: 'measureUrl',
          valueCanonical: url
        }
      end

      if options[:patient_id]
        parameters << {
          name: 'subject',
          valueString: "Patient/#{options[:patient_id]}"
        }
      end

      if options[:patient_id_list]
        parameters << {
          name: 'subjectGroup',
          resource: {
            resourceType: 'Group',
            id: 'test-group-subjectGroup',
            type: 'person',
            actual: true,
            member: options[:patient_id_list].map do |patient_id|
              { entity: { reference: "Patient/#{patient_id}" } }
            end
          }
        }
      end

      parameters << {
        name: 'periodStart',
        valueDate: options[:period_start]
      }

      parameters << {
        name: 'periodEnd',
        valueDate: options[:period_end]
      }

      if options[:data_endpoint]
        parameters << {
          name: 'dataEndpoint',
          resource: JSON.parse(options[:data_endpoint])
        }
      end

      {
        resourceType: 'Parameters',
        parameter: parameters
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
