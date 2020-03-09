require 'spec_helper'

describe 'sensuclassic_check' do
  let(:msg) { 'Found sensuclassic::check' }
  let(:code) { read_fixture('sensuclassic_check.pp') }
  let(:fixed) { read_fixture('sensugo_check.pp') }

  context 'with fix disabled' do
    context 'code ending with an extra newline' do
      it 'should detect a single problem' do
        expect(problems).to have(27).problem
      end

      it 'should create a warning' do
        expect(problems).to contain_warning(msg).on_line(9).in_column(3)
        expect(problems).to contain_warning(msg).on_line(42).in_column(3)
      end

      it 'should create warning for token' do
        msg = 'Found sensuclassic token substitution'
        expect(problems).to contain_warning(msg).on_line(49).in_column(16)
      end
    end
  end

  context 'with fix enabled' do
    before do
      PuppetLint.configuration.fix = true
    end

    after do
      PuppetLint.configuration.fix = false
    end

    context 'code ending with an extra newline' do
      it 'should only detect a single problem' do
        expect(problems).to have(27).problem
      end

      it 'should fix the problem' do
        expect(problems).to contain_fixed(msg).on_line(9).in_column(3)
      end

      it 'should add a newline to the end of the manifest' do
        expect(manifest).to eq(fixed)
      end
    end
  end
end
