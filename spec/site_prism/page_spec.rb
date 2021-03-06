# frozen_string_literal: true

describe SitePrism::Page do
  class BlankPage < SitePrism::Page; end
  class PageWithUrl < SitePrism::Page
    set_url '/bob'
  end
  class PageWithUriTemplate < SitePrism::Page
    set_url '/users{/username}{?query*}'
  end
  class PageWithUrlMatcher < SitePrism::Page
    set_url_matcher(/bob/)
  end

  let(:locator) { instance_double('Capybara::Node::Element') }
  let(:blank_page) { BlankPage.new }
  let(:page_with_url) { PageWithUrl.new }
  let(:page_with_uri_template) { PageWithUriTemplate.new }
  let(:page_with_url_matcher) { PageWithUrlMatcher.new }

  before do
    allow(SitePrism::Waiter).to receive(:default_wait_time).and_return(0)
  end

  it 'responds to set_url' do
    expect(described_class).to respond_to(:set_url)
  end

  it 'responds to set_url_matcher' do
    expect(described_class).to respond_to(:set_url_matcher)
  end

  it 'should be able to set a url against it' do
    expect(page_with_url.url).to eq('/bob')
  end

  it 'url should be nil by default' do
    expect(blank_page.url).to be_nil
  end

  it 'url matcher should be nil by default' do
    expect(BlankPage.url_matcher).to be_nil

    expect(blank_page.url_matcher).to be_nil
  end

  it 'should be able to set a url matcher against it' do
    expect(page_with_url_matcher.url_matcher).to eq(/bob/)
  end

  it 'should allow calls to displayed? if the url matcher has been set' do
    expect { page_with_url_matcher.displayed? }.not_to raise_error
  end

  it "should raise an exception if displayed? \
is called before the matcher has been set" do
    expect { blank_page.displayed? }
      .to raise_error(SitePrism::NoUrlMatcherForPageError)
  end

  it 'should expose the page title' do
    expect(blank_page).to respond_to(:title)
  end

  it 'should raise an exception if passing a block to an element' do
    expect { CSSPage.new.element_one { :any_old_block } }
      .to raise_error(SitePrism::UnsupportedBlockError)
  end

  it 'should raise an exception if passing a block to elements' do
    expect { CSSPage.new.elements_one { :any_old_block } }
      .to raise_error(SitePrism::UnsupportedBlockError)
  end

  it 'should raise an exception if passing a block to sections' do
    expect { CSSPage.new.sections_one { :any_old_block } }
      .to raise_error(SitePrism::UnsupportedBlockError)
  end

  it { is_expected.to respond_to(*Capybara::Session::DSL_METHODS) }

  describe '#page' do
    subject { page_with_url.page }

    context 'with #load called previously' do
      before { page_with_url.instance_variable_set(:@page, :some_value) }

      it { is_expected.to eq(:some_value) }
    end

    context 'with #load not called previously' do
      it { is_expected.to eq(Capybara.current_session) }
    end
  end

  describe '#load' do
    class PageWithLoadValidations < SitePrism::Page
      set_url '/foo_page'

      def must_be_true
        true
      end

      def also_true
        true
      end

      def foo?
        true
      end

      load_validation { [must_be_true, 'It is not true!'] }
      load_validation { [also_true, 'It is not also true!'] }
    end

    let(:page_with_load_validations) { PageWithLoadValidations.new }

    it "should not allow loading if the url hasn't been set" do
      expect { blank_page.load }
        .to raise_error(SitePrism::NoUrlForPageError)
    end

    it 'should allow loading if the url has been set' do
      expect { page_with_url.load }.not_to raise_error
    end

    it 'should allow expansions if the url has them' do
      expect { page_with_uri_template.load(username: 'foobar') }.not_to raise_error

      expect(
        page_with_uri_template
        .url(username: 'foobar', query: { 'recent_posts' => 'true' })
      ).to eq('/users/foobar?recent_posts=true')

      expect(page_with_uri_template.url).to eq('/users')
    end

    it 'should allow to load html' do
      expect { page_with_url.load('<html/>') }.not_to raise_error
    end

    context 'with Passing Load Validations' do
      it 'executes the block' do
        expect(page_with_load_validations.load).to be_truthy
      end

      context 'when validations are disabled' do
        it 'executes the block' do
          expect(page_with_load_validations.load(with_validations: false)).to be_truthy
        end
      end
    end

    context 'With Failing Load Validations' do
      it 'raises an error' do
        allow(page_with_load_validations)
          .to receive(:must_be_true).and_return(false)

        expect { page_with_load_validations.load }
          .to raise_error(SitePrism::FailedLoadValidationError)
          .with_message('It is not true!')
      end

      context 'when validations are disabled' do
        it 'executes the block' do
          allow(page_with_load_validations)
            .to receive(:must_be_true).and_return(false)

          expect(page_with_load_validations.load(with_validations: false)).to be_truthy
        end
      end
    end

    context 'when passed a block' do
      it 'should allow to load html and yields itself' do
        expect(blank_page.load('<html>hi<html/>', &:text)).to eq('hi')
      end

      context 'with Passing Load Validations' do
        it 'executes the block' do
          expect(page_with_load_validations.load { :return_this })
            .to eq(:return_this)
        end

        it 'yields itself to the passed block' do
          expect(page_with_load_validations).to receive(:foo?).and_call_original

          page_with_load_validations.load(&:foo?)
        end

        context 'when validations are disabled' do
          it 'executes the block' do
            expect(page_with_load_validations.load(with_validations: false) { :return_this })
              .to eq(:return_this)
          end
        end
      end

      context 'With Failing Load Validations' do
        it 'raises an error' do
          allow(page_with_load_validations)
            .to receive(:must_be_true).and_return(false)

          expect { page_with_load_validations.load { puts 'foo' } }
            .to raise_error(SitePrism::FailedLoadValidationError)
            .with_message('It is not true!')
        end

        context 'when validations are disabled' do
          it 'executes the block' do
            allow(page_with_load_validations)
              .to receive(:must_be_true).and_return(false)

            expect(page_with_load_validations.load(with_validations: false) { :return_this })
              .to eq(:return_this)
          end
        end
      end
    end
  end

  describe '#displayed?' do
    it 'delegates through #wait_until_displayed' do
      expect(page_with_url).to receive(:wait_until_displayed).with(:foo, :bar, :baz)

      page_with_url.displayed?(:foo, :bar, :baz)
    end

    context 'with a full string URL matcher' do
      class PageWithStringFullUrlMatcher < SitePrism::Page
        set_url_matcher('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')
      end

      let(:page) { PageWithStringFullUrlMatcher.new }

      it 'matches with all elements matching' do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be true
      end

      it "doesn't match with a non-matching fragment" do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#otherfr')

        expect(page.displayed?).to be false
      end

      it "doesn't match with a missing param" do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz#frag')

        expect(page.displayed?).to be false
      end

      it "doesn't match with wrong path" do
        swap_current_url('https://joe:bump@bla.org:443/not_foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be false
      end

      it "doesn't match with wrong host" do
        swap_current_url('https://joe:bump@blabber.org:443/foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be false
      end

      it "doesn't match with wrong user" do
        swap_current_url('https://joseph:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be false
      end

      it "doesn't match with wrong password" do
        swap_current_url('https://joe:bean@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be false
      end

      it "doesn't match with wrong scheme" do
        swap_current_url('http://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be false
      end

      it "doesn't match with wrong port" do
        swap_current_url('https://joe:bump@bla.org:8000/foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be false
      end
    end

    context 'with a minimal URL matcher' do
      class PageWithStringMinimalUrlMatcher < SitePrism::Page
        set_url_matcher('/foo')
      end

      let(:page) { PageWithStringMinimalUrlMatcher.new }

      it 'matches a complex URL by only path' do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect(page.displayed?).to be true
      end
    end

    context 'with an implicit matcher' do
      class PageWithImplicitUrlMatcher < SitePrism::Page
        set_url '/foo'
      end

      let(:page) { PageWithImplicitUrlMatcher.new }

      it 'should default the matcher to the url' do
        expect(page.url_matcher).to eq('/foo')
      end

      it 'matches a realistic local dev URL' do
        swap_current_url('http://localhost:3000/foo')

        expect(page.displayed?).to be true
      end
    end

    context 'with a parameterized URL matcher' do
      class PageWithParameterizedUrlMatcher < SitePrism::Page
        set_url_matcher('{scheme}:///foos{/id}')
      end

      let(:page) { PageWithParameterizedUrlMatcher.new }

      it 'returns true without expected_mappings provided' do
        swap_current_url('http://localhost:3000/foos/28')

        expect(page.displayed?).to be true
      end

      it 'returns true with correct expected_mappings provided' do
        swap_current_url('http://localhost:3000/foos/28')

        expect(page.displayed?(id: 28)).to be true
      end

      it 'returns false with incorrect expected_mappings provided' do
        swap_current_url('http://localhost:3000/foos/28')

        expect(page.displayed?(id: 17)).to be false
      end

      it "passes through incorrect expected_mappings \
from the be_displayed matcher" do
        swap_current_url('http://localhost:3000/foos/28')

        expect(page).not_to be_displayed(id: 17)
      end

      it "passes through correct expected_mappings \
from the be_displayed matcher" do
        swap_current_url('http://localhost:3000/foos/28')

        expect(page).to be_displayed(id: 28)
      end
    end

    context 'with a bogus URL matcher' do
      class PageWithBogusFullUrlMatcher < SitePrism::Page
        set_url_matcher(this: "isn't a URL matcher")
      end

      let(:page) { PageWithBogusFullUrlMatcher.new }

      it 'raises InvalidUrlMatcherError' do
        expect { page.displayed? }
          .to raise_error(SitePrism::InvalidUrlMatcherError)
      end
    end
  end

  describe '#wait_until_displayed' do
    subject { page.wait_until_displayed }

    context 'with a full string URL matcher' do
      class PageWithStringFullUrlMatcher < SitePrism::Page
        set_url_matcher('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')
      end

      let(:page) { PageWithStringFullUrlMatcher.new }

      it 'matches with all elements matching' do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect { subject }.not_to raise_error
      end

      it "doesn't match with a non-matching fragment" do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#otherfr')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end

      it "doesn't match with a missing param" do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz#frag')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end

      it "doesn't match with wrong path" do
        swap_current_url('https://joe:bump@bla.org:443/not_foo?bar=baz&bar=boof#frag')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end

      it "doesn't match with wrong host" do
        swap_current_url('https://joe:bump@blabber.org:443/foo?bar=baz&bar=boof#frag')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end

      it "doesn't match with wrong user" do
        swap_current_url('https://joseph:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end

      it "doesn't match with wrong password" do
        swap_current_url('https://joe:bean@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end

      it "doesn't match with wrong scheme" do
        swap_current_url('http://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end

      it "doesn't match with wrong port" do
        swap_current_url('https://joe:bump@bla.org:8000/foo?bar=baz&bar=boof#frag')

        expect { subject }.to raise_error(SitePrism::TimeoutError)
      end
    end

    context 'with a minimal URL matcher' do
      class PageWithStringMinimalUrlMatcher < SitePrism::Page
        set_url_matcher('/foo')
      end

      let(:page) { PageWithStringMinimalUrlMatcher.new }

      it 'matches a complex URL by only path' do
        swap_current_url('https://joe:bump@bla.org:443/foo?bar=baz&bar=boof#frag')

        expect { subject }.not_to raise_error
      end
    end

    context 'with an implicit matcher' do
      class PageWithImplicitUrlMatcher < SitePrism::Page
        set_url '/foo'
      end

      let(:page) { PageWithImplicitUrlMatcher.new }

      it 'should default the matcher to the url' do
        expect(page.url_matcher).to eq('/foo')
      end

      it 'matches a realistic local dev URL' do
        swap_current_url('http://localhost:3000/foo')

        expect { subject }.not_to raise_error
      end
    end

    context 'with a parameterized URL matcher' do
      class PageWithParameterizedUrlMatcher < SitePrism::Page
        set_url_matcher('{scheme}:///foos{/id}')
      end

      let(:page) { PageWithParameterizedUrlMatcher.new }

      it 'passes without expected_mappings provided' do
        swap_current_url('http://localhost:3000/foos/28')

        expect { page.wait_until_displayed }.not_to raise_error
      end

      it 'passes with correct expected_mappings provided' do
        swap_current_url('http://localhost:3000/foos/28')

        expect { page.wait_until_displayed(id: 28) }.not_to raise_error
      end

      it 'fails with incorrect expected_mappings provided' do
        swap_current_url('http://localhost:3000/foos/28')

        expect { page.wait_until_displayed(id: 17) }.to raise_error(SitePrism::TimeoutError)
      end
    end

    context 'with a bogus URL matcher' do
      class PageWithBogusFullUrlMatcher < SitePrism::Page
        set_url_matcher(this: "isn't a URL matcher")
      end

      let(:page) { PageWithBogusFullUrlMatcher.new }

      it 'raises InvalidUrlMatcherError' do
        expect { subject }.to raise_error(SitePrism::InvalidUrlMatcherError)
      end
    end
  end

  describe '#url_matches' do
    context 'with a templated matcher' do
      class PageWithParameterizedUrlMatcher < SitePrism::Page
        set_url_matcher('{scheme}:///foos{/id}')
      end

      let(:page) { PageWithParameterizedUrlMatcher.new }

      it 'returns mappings from the current_url' do
        swap_current_url('http://localhost:3000/foos/15')

        expect(page.url_matches).to eq('scheme' => 'http', 'id' => '15')
      end

      it "returns nil if current_url doesn't match the url_matcher" do
        swap_current_url('http://localhost:3000/bars/15')

        expect(page.url_matches).to be_nil
      end
    end

    context 'with a regexp matcher' do
      class PageWithRegexpUrlMatcher < SitePrism::Page
        set_url_matcher(/foos\/(\d+)/)
      end

      let(:page) { PageWithRegexpUrlMatcher.new }

      it 'returns regexp MatchData' do
        swap_current_url('http://localhost:3000/foos/15')

        expect(page.url_matches).to be_kind_of(MatchData)
      end

      it 'lets you get at the captures' do
        swap_current_url('http://localhost:3000/foos/15')

        expect(page.url_matches[1]).to eq('15')
      end

      it "returns nil if current_url doesn't match the url_matcher" do
        swap_current_url('http://localhost:3000/bars/15')

        expect(page.url_matches).to be nil
      end
    end

    context 'with a bogus URL matcher' do
      class PageWithBogusFullUrlMatcher < SitePrism::Page
        set_url_matcher(this: "isn't a URL matcher")
      end

      let(:page) { PageWithBogusFullUrlMatcher.new }

      it 'raises InvalidUrlMatcherError' do
        expect { page.url_matches }
          .to raise_error(SitePrism::InvalidUrlMatcherError)
      end
    end
  end

  describe '#execute_script' do
    it 'delegates through Capybara.current_session' do
      expect(Capybara.current_session)
        .to receive(:execute_script)
        .with('JUMP!')

      blank_page.execute_script('JUMP!')
    end
  end

  describe '#evaluate_script' do
    it 'delegates through Capybara.current_session' do
      expect(Capybara.current_session)
        .to receive(:evaluate_script)
        .with('How High?')
        .and_return('To the sky!')

      expect(blank_page.evaluate_script('How High?')).to eq('To the sky!')
    end
  end

  describe '#secure?' do
    let(:page) { blank_page }

    it 'is true for secure pages' do
      swap_current_url('https://www.secure.com/')

      expect(page).to be_secure
    end

    it 'is false for insecure pages' do
      swap_current_url('http://www.insecure.com/')

      expect(page).not_to be_secure
    end

    it 'is false for pages where the prefix is www' do
      swap_current_url('www.unsure.com')

      expect(page).not_to be_secure
    end
  end

  def swap_current_url(url)
    allow(page).to receive(:page).and_return(instance_double('FakedPage', current_url: url))
  end
end
