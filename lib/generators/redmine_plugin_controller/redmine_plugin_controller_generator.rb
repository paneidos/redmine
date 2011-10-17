class RedminePluginControllerGenerator < Rails::Generators::NamedBase 
  argument :plugin_name, :type => :string
  argument :actions, :type => :array, :default => [], :banner => "action action"
  check_class_collision :suffix => "Controller"

  source_root File.expand_path('../templates', __FILE__)

  def generate_controller
    # Controller class, functional test, and helper class.
    template 'controller.rb.erb',
                  File.join("vendor/plugins/redmine_#{plugin_name}/app/controllers",
                          class_path,
                          "#{file_name}_controller.rb")

    template 'functional_test.rb.erb',
                File.join("vendor/plugins/redmine_#{plugin_name}/test/functional",
                          class_path,
                          "#{file_name}_controller_test.rb")

    template 'helper.rb.erb',
                File.join("vendor/plugins/redmine_#{plugin_name}/app/helpers",
                          class_path,
                          "#{file_name}_helper.rb")

    # View template for each action.
    actions.each do |action|
      path = File.join("vendor/plugins/redmine_#{plugin_name}/app/views", class_path, file_name, "#{action}.html.erb")
      @action = action
      template 'view.html.erb', path, :assigns => { :action => action, :path => path }
    end
  end
  
  def add_routes
    actions.reverse.each do |action|
      route %{get "#{file_name}/#{action}"}
    end
  end
  
end
