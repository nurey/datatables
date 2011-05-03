module DataTablesHelper
  def datatables(source, *attrs)
    datatable = controller.datatable_source(source)
    html_opts = []
    if attrs.last
      attrs.last.each { |k,v| html_opts << "#{k}=\"#{v}\"" }
    end
    html_opts = html_opts.join(' ')
    
    columns = datatable[:attrs].collect { |a| "<th>#{a}</th>" }.join
    column_nulls = datatable[:attrs].slice(1..-1).collect { |a| "null" }.join ","
    table_header = "<tr>#{columns}</tr>"
    url = method("#{datatable[:action]}_url".to_sym).call
    html = "
<script>
$(document).ready(function() {
  $('##{datatable[:action]}').dataTable({
    sDom: 'C<\"clear\">lfrtip',
    bJQueryUI: true,
    bProcessing: true,
		bServerSide: true,
		bAutoWidth: false,
		sAjaxSource: \"#{url}\",
		oColVis: {
			aiExclude: [ 0 ]
		},
		aoColumns: [
				{
				  bSearchable: false,
	        bSortable: false
				},
        #{column_nulls}
			],
  });
});
</script>
<table id=\"#{datatable[:action]}\" #{html_opts}>
<thead>
#{table_header}
</thead>
<tbody>
</tbody>
</table>
"
    return raw(html)
  end
end