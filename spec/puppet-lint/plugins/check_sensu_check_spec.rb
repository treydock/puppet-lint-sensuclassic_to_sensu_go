require 'spec_helper'

describe 'sensu_check' do
  let(:code) { read_fixture('sensu_check_before.pp') }
  let(:fixed) { read_fixture('sensu_check_after.pp') }

  context 'with fix disabled' do
    context 'code with errors' do
      it 'should detect problems' do
        expect(problems).to have(4).problem
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
        expect(problems).to have(4).problem
      end

      it 'should add a newline to the end of the manifest' do
        expect(manifest).to eq(fixed)
      end
    end
  end
end
