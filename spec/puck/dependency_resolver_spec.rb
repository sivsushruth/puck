# encoding: utf-8

require 'spec_helper'


module Puck
  describe DependencyResolver do
    describe '#resolve_gem_dependencies' do
      let :resolved_gem_dependencies do
        Dir.chdir(app_dir_path) do
          described_class.new.resolve_gem_dependencies(options)
        end
      end

      let :app_dir_path do
        File.expand_path('../../resources/example_app', __FILE__)
      end

      let :gem_home do
        gemset_name = File.read(File.join(app_dir_path, '.ruby-gemset')).strip
        File.join(ENV['HOME'], '.rvm', 'gems', "#{ENV['RUBY_VERSION']}@#{gemset_name}")
      end

      let :options do
        {
          gem_home: gem_home,
        }
      end

      let :tmp_dir do
        Dir.mktmpdir
      end

      after do
        FileUtils.rm_rf(tmp_dir)
      end

      it 'includes the gem name in the specification' do
        gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
        gem_names.should include('grape')
        gem_names.should include('i18n')
      end

      it 'includes the versioned gem name in the specification' do
        versioned_gem_names = resolved_gem_dependencies.map { |gem| gem[:versioned_name] }
        versioned_gem_names.should include('grape-0.4.1')
        versioned_gem_names.should include('i18n-0.6.1')
      end

      it 'includes the gem\'s base path in the specification' do
        base_paths = resolved_gem_dependencies.map { |gem| Pathname.new(gem[:base_path]) }
        base_paths.each do |base_path|
          base_path.should be_directory, "expected #{base_path} to be a directory"
        end
      end

      it 'includes relative loads paths in the specification' do
        load_paths = resolved_gem_dependencies.flat_map { |gem| gem[:load_paths].map { |load_path| File.join(gem[:versioned_name], load_path) } }
        load_paths.should include('grape-0.4.1/lib')
        load_paths.should include('i18n-0.6.1/lib')
      end

      it 'includes the relative bin path in the specification' do
        load_paths = resolved_gem_dependencies.map { |gem| File.join(gem[:versioned_name], gem[:bin_path]) }
        load_paths.should include('grape-0.4.1/bin')
        load_paths.should include('i18n-0.6.1/bin')
      end

      it 'correctly handles gems with a specific platform' do
        specification = resolved_gem_dependencies.find { |gem| gem[:name] == 'puma' }
        File.basename(specification[:base_path]).should == 'puma-2.0.1-java'
      end

      it 'supports git dependencies' do
        specification = resolved_gem_dependencies.find { |gem| gem[:name] == 'rack-contrib' }
        specification[:load_paths].should include('lib')
      end

      it 'only includes gems from the "default" group by default' do
        gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
        gem_names.should_not include('pry', 'rspec', 'rack-cache', 'rack-mini-profile')
      end

      it 'fails if a gem is not installed' do
        options[:gem_groups] = [:not_installed]
        expect do
          resolved_gem_dependencies
        end.to raise_error(/rack-mini-profile/)
      end

      it 'returns each gem only once, even if it is a dependency of multiple gems' do
        specifications = resolved_gem_dependencies.select { |gem| gem[:name] == 'rack' }
        specifications.should have(1).specification
      end

      it 'supports gems with names that are not the same as the repository they are installed from' do
        specifications = resolved_gem_dependencies.select { |gem| gem[:name] == 'qu-redis' }
        specifications.should have(1).specification
      end

      it 'should not include bundler itself' do
        specification = resolved_gem_dependencies.find { |gem| gem[:name] == 'bundler' }
        specification.should be_nil
      end

      context 'with custom groups' do
        let :options do
          super.merge(gem_groups: [:default, :extra])
        end

        it 'includes gems from the specified groups' do
          gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
          gem_names.should include('grape', 'rack-cache')
        end

        it 'does not write a bundle configuration' do
          bundler_config = Pathname.new(app_dir_path).join('.bundle', 'config')
          bundler_config.should_not exist
        end
      end
    end
  end
end