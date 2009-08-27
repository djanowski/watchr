require 'test/test_helper'

class TestRunner < Test::Unit::TestCase
  include Watchr

  def teardown
    Fixture.delete_all
    Watchr.options = nil
  end

  test "maps observed files to their pattern and the actions they trigger" do
    file_a = Fixture.create('a.rb')
    file_b = Fixture.create('b.rb')
    script = Script.new
    script.watch(file_a.pattern) { 'ohaie' }
    script.watch(file_b.pattern) { 'kthnx' }

    runner = Runner.new(script)
    runner.map[file_a.rel][0].should be(file_a.pattern)
    runner.map[file_b.rel][0].should be(file_b.pattern)
    runner.map[file_a.rel][1].call.should be('ohaie')
    runner.map[file_b.rel][1].call.should be('kthnx')
  end

  test "latest mtime" do
    file_a = Fixture.create('a.rb')
    file_b = Fixture.create('b.rb')
    script = Script.new
    script.watch(file_a.pattern) { 'ohaie' }
    script.watch(file_b.pattern) { 'kthnx' }

    runner = Runner.new(script)
    file_a.touch

    runner.last_updated_file.rel.should be(file_a.rel)
  end

  test "monitors file changes" do
    file_a = Fixture.create('a.rb')
    script = Script.new
    script.watch(file_a.pattern) { nil }

    runner = Runner.new(script)
    runner.changed?.should be(false)

    # fake Kernel.sleep(2)
    file_a.mtime     = Time.now - 2
    runner.init_time = Time.now - 2

    file_a.touch
    runner.changed?.should be(true)
  end

  test "calls action corresponding to file changed" do
    script = Script.new
    script.watch(Fixture.create.pattern) { throw(:ohaie) }

    runner = Runner.new(script)
    runner.init_time = Time.now - 2
    runner.changed?
    assert_throws(:ohaie) do
      runner.instance_eval { call_action! }
    end
  end

  test "passes match data to action" do
    file_a = Fixture.create('a.rb')
    script = Script.new
    pattern = Fixture::DIR.join('(.*)\.(.*)$').rel
    script.watch((pattern)) {|md| [md[1], md[2]].join('|') }

    runner = Runner.new(script)
    runner.init_time = Time.now - 2
    file_a.touch
    runner.changed?
    runner.instance_eval { call_action! }.should be('a|rb')
  end

  test "doesn't run at startup" do
    file   = Fixture.create('a.rb')
    script = Script.new
    script.watch(file.pattern) { nil }

    runner = Runner.new(script)
    runner.changed?.should be(false)
  end

  test "a path only triggers its last matching pattern's action" do
    file_a = Fixture.create('fix_a.rb')
    file_b = Fixture.create('fix_b.rb')
    script = Script.new
    script.watch('fix_a\.rb')  { throw(:ohaie) }
    script.watch('fix_.*\.rb') { throw(:kkthx) }

    runner = Runner.new(script)
    runner.init_time = Time.now - 2
    file_a.touch
    runner.changed?
    assert_throws(:kkthx) do
      runner.instance_eval { call_action! }
    end
  end

  test "updates map when script changes" do
    file_a = Fixture.create('aaa')
    file_b = Fixture.create('bbb')
    script = Fixture.create('script.watchr', "watch('aaa')")

    # fake Kernel.sleep(2)
    script.mtime = Time.now - 2

    runner = Runner.new(script)
    assert runner.paths.first.match('aaa')

    Fixture.create('script.watchr', "watch('bbb')")

    runner.trigger
    assert runner.paths.first.match('bbb')
  end
end