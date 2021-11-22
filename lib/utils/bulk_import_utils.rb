# frozen_string_literal: true

module DEQMTestKit
  # Utility functions in support of the bulk import test group
  module BulkImportUtils
    def get_retry_or_backoff_time(wait_time, reply)
      retry_after = -1
      is_retry_nil = reply[:headers].find { |h| h.name == 'retry_after' }
      unless is_retry_nil.nil?
        retry_after = is_retry_nil.to_i || -1
      end

      if retry_after.positive?
        retry_after
      else
        wait_time * 2
      end
    end
  end
end
