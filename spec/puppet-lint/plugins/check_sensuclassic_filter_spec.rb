require 'spec_helper'

describe 'sensuclassic_filter' do
  let(:code) { read_fixture('sensuclassic_filter.pp') }
  let(:fixed) { read_fixture('sensugo_filter.pp') }

  context 'with fix disabled' do
    context 'code ending with an extra newline' do
      it 'should detect a single problem' do
        expect(problems).to have(2).problem
      end

      it 'should create a warning' do
        expect(problems).to contain_warning('Found sensuclassic::filter').on_line(6).in_column(3)
        expect(problems).to contain_warning('Found sensuclassic_filter').on_line(15).in_column(3)
      end
    end
  end

  context 'with fix enabled', skip: 'Not supported' do
    before do
      PuppetLint.configuration.fix = true
    end

    after do
      PuppetLint.configuration.fix = false
    end

    context 'code ending with an extra newline' do
      it 'should only detect a single problem' do
        expect(problems).to have(2).problem
      end

      it 'should fix the problem' do
        expect(problems).to contain_fixed('Found sensuclassic::filter').on_line(6).in_column(3)
        expect(problems).to contain_fixed('Found sensuclassic_filter').on_line(15).in_column(3)
      end

      it 'should add a newline to the end of the manifest' do
        expect(manifest).to eq(fixed)
      end
    end
  end
end
