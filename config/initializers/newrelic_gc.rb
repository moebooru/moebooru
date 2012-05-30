# Enables Garbage Collection profiling for newrelic use.
if RUBY_VERSION >= '1.9'
  GC::Profiler.enable
else
  # REE has GC.enable_stats. we'll try enabling it.
  # Do nothing on error.
  begin
    GC.enable_stats
  rescue
  end
end
