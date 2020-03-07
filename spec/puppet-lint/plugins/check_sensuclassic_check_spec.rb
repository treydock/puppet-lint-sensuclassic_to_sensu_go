require 'spec_helper'

describe 'sensuclassic_check' do
  let(:msg) { 'Found sensuclassic::check' }
  let(:code) { read_fixture('sensuclassic_check.pp') }
  let(:fixed) { read_fixture('sensugo_check.pp') }

  context 'with fix disabled' do
    context 'code ending with an extra newline' do
      it 'should detect a single problem' do
        expect(problems).to have(15).problem
      end

      it 'should create a warning' do
        expect(problems).to contain_warning(msg).on_line(7).in_column(3)
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
        expect(problems).to have(15).problem
      end

      it 'should fix the problem' do
        expect(problems).to contain_fixed(msg).on_line(7).in_column(3)
      end

      it 'should add a newline to the end of the manifest' do
        expect(manifest).to eq(fixed)
      end
    end
  end
end
