class RedminePluginModelGenerator < Rails::Generators::NamedBase
  argument :plugin_name, :type => :string
  argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"
  hook_for :orm, :required => true
  check_class_collision :suffix => "Test"
  
  source_root File.expand_path('../templates', __FILE__)

  def generate_model
    # Model class, unit test, and fixtures.
    template 'model.rb.erb',      File.join("vendor/plugins/redmine_#{plugin_name}/app/models", class_path, "#{file_name}.rb")
    template 'unit_test.rb.erb',  File.join("vendor/plugins/redmine_#{plugin_name}/test/unit", class_path, "#{file_name}_test.rb")

    unless options[:skip_fixture] 
     	template 'fixtures.yml',  File.join("vendor/plugins/redmine_#{plugin_name}/test/fixtures", "#{table_name}.yml")
    end

    unless options[:skip_migration]
      @migration_name = "Create#{class_name.pluralize.gsub(/::/, '')}"
      @migration_file_name = "create_#{file_path.gsub(/\//, '_').pluralize}"
      template 'migration.rb.erb', "vendor/plugins/redmine_#{plugin_name}/db/migrate"
    end
  end
end
