module DataTablesController
  def self.included(cls)
    cls.extend(ClassMethods)
  end
  
  module ClassMethods
    def datatables_source(action, model, *attrs)
      modelCls = Kernel.const_get(model.to_s.split("_").collect(&:capitalize).join)
      modelAttrs = modelCls.new.attributes
      
      columns = []
      modelAttrs.each_key { |k| columns << k }
      
      options = {}
      attrs.each do |option|
        option.each { |k,v| options[k] = v }
      end

      # override columns
      columns = options_to_columns(options) if options[:columns]
      
      conditions = options[:conditions] || []
      join_tables = options[:join_tables] || []

      # define columns so they are accessible from the helper
      define_columns(modelCls, columns, action)
            
      # define method that returns the data for the table
      define_datatables_action(self, action, modelCls, conditions, columns, join_tables)
    end

    def define_datatables_action(controller, action, modelCls, conditions, columns,join_tables)      
      define_method action.to_sym do
        total_records = modelCls.count :conditions => conditions.join(" AND ")

        unless params[:sSearch].blank?
          search_conditions = []
          columns.find_all { |col| col.has_key?(:attribute) }.each do |col|
            search_conditions << "(text(#{col[:attribute]}) ILIKE '%%#{params[:sSearch]}%%')"
          end
          conditions << '(' + search_conditions.join(" OR ") + ')'
        end
        joined_conditions = conditions.join(" AND ")
         
        total_display_records = modelCls.count :conditions => joined_conditions
        
        sort_column = params[:iSortCol_0].to_i
        sort_column = 1 if sort_column == 0
        current_page = (params[:iDisplayStart].to_i/params[:iDisplayLength].to_i rescue 0)+1
        objects = modelCls.paginate(:page => current_page, 
                                    :order => "#{columns[sort_column][:name]} #{params[:sSortDir_0]}", 
                                    :conditions => joined_conditions,
                                    :include => join_tables,
                                    :per_page => params[:iDisplayLength])
        data = objects.collect do |instance|
          columns.collect { |column| datatables_instance_get_value(instance, column) }
        end
        render :text => {:iTotalRecords => total_records, 
                         :iTotalDisplayRecords => total_display_records,
                         :aaData => data, 
                         :sEcho => params[:sEcho].to_i}.to_json
      end
    end
    
    private
    
    #
    # Takes a list of columns from options and transforms them
    #
    def options_to_columns(options)
      columns = []
      options[:columns].each do |column|
        if column.kind_of? Symbol # a column from the database, we don't need to do anything
          columns << {:name => column, :attribute => column}
        elsif column.kind_of? Hash
          columns << {:name => column[:name], :special => column}
        end
      end
      columns
    end
    
    def define_columns(cls, columns, action)
      define_method "datatable_#{action}_columns".to_sym do
        columnNames = []
        columns.each do |column|
          if column[:method] or column[:eval]
            columnNames << I18n.t(column[:name], :default => column[:name].to_s)
          else
            columnNames << I18n.t(column[:name].to_sym, :default => column[:name].to_s)
          end
        end
        columnNames
      end
    end
  end
  
  # gets the value for a column and row
  def datatables_instance_get_value(instance, column)
    if column[:attribute]
      val = instance.send(column[:attribute].to_sym)
      return I18n.t(val.to_s.to_sym, :default => val.to_s) if not val.nil?
      return ''
    elsif column[:special]
      special = column[:special]
      
      if special[:method]
        return method(special[:method].to_sym).call(instance)
      elsif special[:eval]
        proc = lambda { obj = instance; binding }
        return Kernel.eval(special[:eval], proc.call)
      end
    end
    return "value not found"
  end
  
  def datatable_source(name)
    {:action => name, :attrs => method("datatable_#{name}_columns".to_sym).call}
  end
end
