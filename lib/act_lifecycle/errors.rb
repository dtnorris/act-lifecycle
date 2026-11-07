# frozen_string_literal: true

module ActLifecycle
  # Reports unsafe or busy reservations. Accepts ordinary StandardError message
  # inputs; callers may translate this package-local error at their own facade.
  class InvalidState < StandardError; end
end
