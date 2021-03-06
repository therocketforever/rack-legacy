require 'minitest/autorun'
require 'rack/legacy'
require 'rack/legacy/cgi'

class CgiTest < MiniTest::Unit::TestCase

  def test_valid?
    assert app.valid?(fixture_file('success.cgi')) # Valid file
    assert !app.valid?(fixture_file('success.php')) # Valid file but not executable
    assert !app.valid?(fixture_file('../unit/cgi_test.rb')) # Valid file but outside public
    assert !app.valid?(fixture_file('missing.cgi')) # File not found
    assert !app.valid?(fixture_file('./')) # Directory
  end

  def test_call
    assert_equal \
      [200, {"Content-Type"=>"text/html", "Content-Length"=>"7"}, 'Success'],
      call({'PATH_INFO' => 'success.cgi', 'REQUEST_METHOD' => 'GET'})
    assert_equal \
      [200, {"Content-Type"=>"text/html"}, 'Endpoint'],
      call({'PATH_INFO' => 'missing.cgi'})
    assert_equal [200, {}, ''],
      call({'PATH_INFO' => 'empty.cgi', 'REQUEST_METHOD' => 'GET'})
    assert_equal [404, {"Content-Type"=>"text/html"}, ''],
      call({'PATH_INFO' => '404.cgi', 'REQUEST_METHOD' => 'GET'})
    assert_equal [200, {"Content-Type"=>"text/html", 'Set-Cookie' => "cookie1\ncookie2"}, ''],
      call({'PATH_INFO' => 'dup_headers.cgi', 'REQUEST_METHOD' => 'GET'})

    assert_raises Rack::Legacy::ExecutionError do
      $stderr.reopen open('/dev/null', 'w')
      call({'PATH_INFO' => 'error.cgi', 'REQUEST_METHOD' => 'GET'})
      $stderr.reopen STDERR
    end

    assert_raises Rack::Legacy::ExecutionError do
      $stderr.reopen open('/dev/null', 'w')
      call({'PATH_INFO' => 'syntax_error.cgi', 'REQUEST_METHOD' => 'GET'})
      $stderr.reopen STDERR
    end

    assert_equal \
      [200, {"Content-Type"=>"text/html", "Content-Length"=>"5"}, 'query'],
      call({
        'PATH_INFO' => 'param.cgi',
        'QUERY_STRING' => 'q=query',
        'REQUEST_METHOD' => 'GET'
      })
    assert_equal \
      [200, {"Content-Type"=>"text/html", "Content-Length"=>"4"}, 'post'],
      call({
        'PATH_INFO' => 'param.cgi',
        'REQUEST_METHOD' => 'POST',
        'CONTENT_LENGTH' => '6',
        'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
        'rack.input' => StringIO.new('q=post')
      })

    # NOTE: Not testing multipart forms (and with files) as the functional
    # tests will test that and trying to manually encode data would
    # increase the complexity of the test code more than it was worth.
  end

  def test_environment
    status, headers, body = *call({'PATH_INFO' => 'env.cgi', 'REQUEST_METHOD' => 'GET'})
    env = eval body
    assert File.join(File.dirname(__FILE__), '../fixtures'), env['DOCUMENT_ROOT']
    assert 'Rack Legacy', env['SERVER_SOFTWARE']
  end

  private

  def fixture_file path
    File.expand_path path, File.join(File.dirname(__FILE__), '../fixtures')
  end

  def call env
    status, headers, body = *app.call(env)
    body = body.read
    [status, headers, body]
  end

  def app
    @app ||= Rack::Legacy::Cgi.new \
      proc {[200, {'Content-Type' => 'text/html'}, StringIO.new('Endpoint')]},
      File.join(File.dirname(__FILE__), '../fixtures')
  end

end
