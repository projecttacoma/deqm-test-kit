# frozen_string_literal: true

module DEQMTestKit
  # Utility functions in support of the data requirements test group
  module DataRequirementsUtils
    def get_filter_str(code_filter)
      ret_val = '(no code filter)'

      if code_filter&.code&.first
        code = code_filter.first.code.first
        ret_val = "(#{code.system}|#{code.code})"
      elsif code_filter&.valueSet
        ret_val = "(#{code_filter.valueSet})"
      end

      ret_val
    end

    def get_dr_comparison_list(data_requirement)
      data_requirement.map do |dr|
        cf = dr.codeFilter&.first
        filter_str = get_filter_str cf

        path = cf&.path ? ".#{cf.path}" : ''

        "#{dr.type}#{path}#{filter_str}"
      end
    end

    def get_data_requirements_queries(data_requirements)
      # hashes with { endpoint => FHIR Type, params => { queries } }
      # TODO: keep provenance or decide that it shouldn't be a data requirement query
      queries = data_requirements
                .select { |dr| dr.type && dr.type != 'Provenance' }
                .map do |dr|
        query_for_code_filter(dr.codeFilter&.first, dr.type)
      end

      # TODO: We should be smartly querying for patients based on what the resources reference?
      queries.unshift(endpoint: 'Patient', params: {})
      queries
    end

    def query_for_code_filter(filter, type)
      q = { endpoint: type, params: {} }
      # prefer specific code filter first before valueSet
      if filter&.code&.first
        q[:params][filter.path.to_s] = filter.code[0].code
      elsif filter&.valueSet
        q[:params]["#{filter.path}:in"] = filter.valueSet
      end
      q
    end
  end
end
