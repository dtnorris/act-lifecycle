# frozen_string_literal: true

require "json"
require_relative "../../lib/act_lifecycle"

# One finite real contender. The effect proves the protected block ran; busy or
# unsafe reservations return their package error and never reach that effect.
begin
  value = ActLifecycle::ReservationLock.synchronize(ARGV.fetch(0)) do
    File.binwrite(ARGV.fetch(1), "mutated")
    :acquired
  end
  puts JSON.generate("result" => value)
rescue ActLifecycle::InvalidState => error
  puts JSON.generate("error" => error.message)
  exit 75
end
