require 'spec_helper'

module Bosh::Director::Models
  describe CompiledPackage do
    let(:package) { Package.make }
    let(:stemcell) { Stemcell.make }

    describe '.generate_build_number' do
      it 'returns 1 if no compiled packages for package and stemcell' do
        expect(CompiledPackage.generate_build_number(package, stemcell)).to eq(1)
      end

      it 'returns 2 if only one compiled package exists for package and stemcell' do
        CompiledPackage.make(package: package, stemcell: stemcell, build: 1)
        expect(CompiledPackage.generate_build_number(package, stemcell)).to eq(2)
      end

      it 'will return 1 for new, unique combinations of packages and stemcells' do
        5.times do
          package = Package.make
          stemcell = Stemcell.make

          expect(CompiledPackage.generate_build_number(package, stemcell)).to eq(1)
        end
      end
    end

    describe 'dependency_key_sha1' do
      let(:dependency_key) { 'fake-key' }
      let(:dependency_key_sha1) { Digest::SHA1.hexdigest(dependency_key) }

      context 'when creating new compiled package' do
        it 'generates dependency key sha' do
          compiled_package = CompiledPackage.make(
            package: package,
            stemcell: stemcell,
            dependency_key: dependency_key
          )

          expect(compiled_package.dependency_key_sha1).to eq(dependency_key_sha1)
        end
      end

      context 'when updating existing compiled package' do
        it 'updates dependency key sha' do
          compiled_package = CompiledPackage.make(
            package: package,
            stemcell: stemcell,
            dependency_key: dependency_key
          )

          compiled_package.update dependency_key: 'new-fake-key'
          new_dependency_key_sha1 = Digest::SHA1.hexdigest('new-fake-key')

          expect(compiled_package.dependency_key_sha1).to eq(new_dependency_key_sha1)
        end
      end
    end
  end
end
