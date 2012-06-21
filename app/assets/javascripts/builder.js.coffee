bonnie = @bonnie || {}

class @bonnie.Builder
  constructor: (data_criteria, measure_period) ->
    @measure_period = new bonnie.MeasurePeriod(measure_period)
    @data_criteria = {}
    @populationQuery = new queryStructure.Query()
    @denominatorQuery = new queryStructure.Query()
    @numeratorQuery = new queryStructure.Query()
    @exclusionsQuery = new queryStructure.Query()
    @exceptionsQuery = new queryStructure.Query()
    for key in _.keys(data_criteria)
      @data_criteria[key] = new bonnie.DataCriteria(key, data_criteria[key], @measure_period)

  dataKeys: =>
    _.keys(@data_criteria)

  dataCriteria: (key) =>
    @data_criteria[key]

  updateDisplay: () =>
    alert "updating display: " + @data_criteria

  renderMeasureJSON: (data) =>
    if (!$.isEmptyObject(data.population))
      @populationQuery.rebuildFromJson(data.population)
      @addParamItems(@populationQuery.toJson(),$("#initialPopulationItems"))
      $("#initialPopulationItems .paramGroup").addClass("population")
      
    if (!$.isEmptyObject(data.denominator))
      @denominatorQuery.rebuildFromJson(data.denominator)
      @addParamItems(@denominatorQuery.toJson(),$("#eligibilityMeasureItems"))

    if (!$.isEmptyObject(data.numerator))
      @numeratorQuery.rebuildFromJson(data.numerator)
      @addParamItems(@numeratorQuery.toJson(),$("#outcomeMeasureItems"))

    if (!$.isEmptyObject(data.exclusions))
      @exclusionsQuery.rebuildFromJson(data.exclusions)
      @addParamItems(data.exclusions,$("#exclusionMeasureItems"))

    if (!$.isEmptyObject(data.exceptions))
      @exceptionsQuery.rebuildFromJson(data.exceptions)
      @addParamItems(data.exceptions,$("#exceptionMeasureItems"))
    @._bindClickHandler()
    
  _bindClickHandler: ->
    $('.logicLeaf').click((event) =>
      $('.paramItem').removeClass('editing')
      console.log(event.currentTarget)
      $(event.currentTarget).closest('.paramItem').addClass('editing')
      @editDataCriteria(event.currentTarget))
  
  editDataCriteria: (element) =>
    leaf = $(element)
    data_criteria = @dataCriteria($(element).attr('id'))
    data_criteria.getProperty = (ns) ->
      obj = this
      y = ns.split(".")
      for i in [0..y.length-1]
        if obj[y[i]]
          obj = obj[y[i]]
        else
          return
      obj
    top = $('#workspace > div').css('top')
    $('#workspace').empty();
    element = data_criteria.asHtml('data_criteria_edit')
    element.appendTo($('#workspace'))
    offset = leaf.offset().top + leaf.height()/2 - $('#workspace').offset().top - element.height()/2
    offset = 0 if offset < 0
    maxoffset = $('#measureEditContainer').height() - element.outerHeight(true) - $('#workspace').position().top - $('#workspace').outerHeight(true) + $('#workspace').height()
    offset = maxoffset if offset > maxoffset
    element.css("top", offset)
    arrowOffset = leaf.offset().top + leaf.height()/2 - element.offset().top - $('.arrow-w').outerHeight()/2
    arrowOffset = 0 if arrowOffset < 0
    $('.arrow-w').css('top', arrowOffset)
    element.css("top", top)
    element.animate({top: offset})

    element.find('select[name=status]').val(data_criteria.status)
    element.find('select[name=standard_category]').val(data_criteria.standard_category)

    temporal_element = $(element).find('.temporal_reference')
    $.each(data_criteria.temporal_references, (i, e) ->
      $(temporal_element[i]).find('.temporal_type').val(e.type)
      $(temporal_element[i]).find('.temporal_relation').val(
        (if e.offset && e.offset.value < 0 then 'lt' else 'gt') +
        if e.offset && e.offset.inclusive then 'e' else ''
      )
      $(temporal_element[i]).find('.temporal_value').val(Math.abs(e.offset && e.offset.value) || '')
      $(temporal_element[i]).find('.temporal_unit').val(e.offset && e.offset.unit)
      $(temporal_element[i]).find('.temporal_drop_zone').each((i, e) ->
        fillDrop(e);
      );
    );

    subset_element = $(element).find('.subset_operator')
    $.each(data_criteria.subset_operators, (i, e) ->
      $(subset_element[i]).find('.subset_type').val(e.type)
      if e.range && e.range.low && e.range.low.equals(e.range.high) && e.range.low.inclusive
        $(subset_element[i]).find('.subset_range_type[value=value]').attr('checked', true)
        $(subset_element[i]).find('.subset_range').hide()
      else
        $(subset_element[i]).find('.subset_range_type[value=range]').attr('checked', true)
        $(subset_element[i]).find('.subset_value').hide()
        $(subset_element[i]).find('.subset_range_high_relation').val(if e.range && e.range.high && e.range.high.inclusive then 'lte' else 'lt')
        $(subset_element[i]).find('.subset_range_low_relation').val(if e.range && e.range.low && e.range.low.inclusive then 'gte' else 'gt')
    )

  getNextChildCriteriaId: =>
    id = 1
    id++  while @data_criteria["EncounterEncounterAmbulatoryIncludingPediatrics_precondition_60_CHILDREN_" + id]
    id

  editDataCriteria_submit: (form) =>
    temporal_references = []
    subset_operators = []

    nextId = bonnie.builder.getNextChildCriteriaId()
    $(form).find('.temporal_reference').each((i, e) ->
      temporal_references.push({
        type: $(e).find('.temporal_type').val()
        offset: {
          'inclusive?': $(e).find('.temporal_relation').val().indexOf('e') > -1,
          type: 'PQ',
          unit: $(e).find('.temporal_unit').val(),
          value: $(e).find('.temporal_value').val() * if $(e).find('.temporal_relation').val().indexOf('lt') > -1 then -1 else 1
        } if $(e).find('.temporal_value').val()
        reference: (
          if $(e).find('.temporal_reference_value').length > 1
            $.post('/measures/' + $(form).find('input[type=hidden][name=id]').val() + '/upsert_criteria', {
              criteria_id: (id = $(form).find('input[type=hidden][name=criteria_id]').val() + '_CHILDREN_' + nextId++)
              children_criteria: $.map($(e).find('.temporal_reference_value'), ((e) -> $(e).val()))
              standard_category: 'temporal'
              type: 'derived'
            }) && id
          else $(e).find('.temporal_reference_value').val()
        )
      })
    )
    $(form).find('.subset_operator').each((i, e) ->
      subset_operators.push({
        type: $(e).find('.subset_type').val()
        value: {
          type: 'IVL_PQ'
          high: if $(e).find('.subset_range_type:checked').val() == 'value' then {
            type: 'PQ'
            value: $(e).find('.subset_value_value').val()
            unit: $(e).find('.subset_value_unit').val()
            'inclusive?': true
          } else {
            type: 'PQ'
            value: $(e).find('.subset_range_high_value').val()
            unit: $(e).find('.subset_range_high_unit').val()
            'inclusive?': $(e).find('.subset_range_high_relation').val().indexOf('e') > -1
          } if $(e).find('.subset_range_high_value').val()
          low: if $(e).find('.subset_range_type:checked').val() == 'value' then {
            type: 'PQ'
            value: $(e).find('.subset_value_value').val()
            unit: $(e).find('.subset_value_unit').val()
            'inclusive?': true
          } else {
            type: 'PQ'
            value: $(e).find('.subset_range_low_value').val()
            unit: $(e).find('.subset_range_low_unit').val()
            'inclusive?': $(e).find('.subset_range_low_relation').val().indexOf('e') > -1
          } if $(e).find('.subset_range_low_value').val()
        }
      })
    )
    !$(form).ajaxSubmit({
      data: {
        temporal_references: JSON.stringify(temporal_references)
        subset_operators: JSON.stringify(subset_operators)
      }
      success: (changes) =>
        criteria = @data_criteria[changes.id] = $.extend(@data_criteria[changes.id], changes)
        $element = $('#' + changes.id)
        $element.find('label').text(criteria.buildCategory())
        $('#edit_save_message').empty().append('<span style="color: green">Saved!</span>')
        setTimeout (->
          $("#edit_save_message > span").fadeOut ->
            $(this).remove()
        ), 3000
    });

  addParamItems: (obj,elemParent,container) =>
    #  console.log("called addParamItems with obj=",obj)
    builder = bonnie.builder
    items = obj["items"]
    data_criteria = builder.dataCriteria(obj.id) if (obj.id)
    parent = obj.parent
    makeDropFn = (self) ->
      queryObj = parent ? obj
      dropFunction = (event,ui) ->
        # console.log("inside droppable drop fn")
        console.log(event.srcElement)
        console.log(event)
        target = event.currentTarget
        drop_Y = event.pageY
        child_items = $(@).children(".paramGroup")
        console.log(queryObj)
        for item in child_items
          item_top = $(item).offset().top;
          item_height = $(item).height();
          item_mid = item_top + Math.round(item_height/2)
          # console.log("drop_Y is #{drop_Y} and item_mid is #{item_mid}")
          # if drop_Y > item_mid then console.log("after") else console.log("before")
        tgt = queryObj.parent ? queryObj
        if queryObj instanceof queryStructure.Container then tgt = queryObj else tgt = queryObj.parent
        console.log("queryObj=",queryObj)
        console.log("queryObj instance of Container=",queryObj instanceof queryStructure.Container)
        if queryObj.parent?
          console.log("queryObj.parent=",queryObj.parent)
        else 
          console.log("queryObj has no parent")
        console.log(tgt)
        console.log($(event.target))
        console.log($(event.target).data('criteria-id'))
        tgt.add(
          id: $(event.srcElement).data('criteria-id')
        )
        $(@).removeClass('droppable')
        $('#workspace').empty()
        $("#initialPopulationItems, #eligibilityMeasureItems, #outcomeMeasureItems").empty()
        bonnie.builder.addParamItems(bonnie.builder.populationQuery.toJson(),$("#initialPopulationItems"))
        bonnie.builder.addParamItems(bonnie.builder.denominatorQuery.toJson(),$("#eligibilityMeasureItems"))
        bonnie.builder.addParamItems(bonnie.builder.numeratorQuery.toJson(),$("#outcomeMeasureItems"))
        self._bindClickHandler()
      return dropFunction


    if !$(elemParent).hasClass("droppable")
      # console.log("elemParent=",elemParent)
      $(elemParent).data("query-struct",parent)
      elemParent.droppable(
          over:  @._over
          tolerance:'pointer'
          greedy:true
          accept:'label.ui-draggable'
          out:  @._out
          drop: makeDropFn(@)
  
      )   
    if (data_criteria?)
      if (data_criteria.subset_operators?)
        for subset_operator in data_criteria.subset_operators
          $(elemParent).append("<span class='#{subset_operator.type} subset-operator'>#{subset_operator.title()}</span>")

      if (data_criteria.children_criteria?)
        items = data_criteria.childrenCriteriaItems()
      else
        # we dont have a nested measure clause, add the item to the bottom of the list
        # if (!elemParent.hasClass("paramItem"))
        items = data_criteria.temporalReferenceItems()
        elemParent = bonnie.template('param_group').appendTo(elemParent).find(".paramItem:last")
        data_criteria.asHtml('data_criteria_logic').appendTo(elemParent)

    if ($.isArray(items))
      conjunction = obj['conjunction']
      console.log(container) if container?
      builder.renderParamItems(conjunction, items, elemParent, container)

  _over: ->
    $(@).parents('.paramItem').removeClass('droppable')
    $(@).addClass('droppable')

  _out: ->
    $(@).removeClass('droppable')
    
  renderParamItems: (conjunction, items, elemParent, container) =>
    builder = bonnie.builder

    elemParent = bonnie.template('param_group').appendTo(elemParent).find(".paramItem:last") if items.length > 1 and !container?

    $.each(items, (i,node) ->
      if (node.temporal)
        $(elemParent).append("<span class='#{node.conjunction} temporal-operator'>#{node.title}</span><span class='block-down-arrow'></span>")

      # if (!container and i == 0)
      #   if (!node.temporal && !node.items?)
      #     elemParent = bonnie.template('param_group').appendTo(elemParent).find(".paramItem:last")

      builder.addParamItems(node,elemParent)

      if (i < items.length-1 and !node.temporal)
        next = items[i+1]
        negation = ''
        negation = ' not' if (next['negation'])
        conjunction = node.conjunction if !conjunction
        $(elemParent).append("<span class='"+conjunction+negation+"'>"+conjunction+negation+"</span>"))


  toggleDataCriteriaTree: (element) =>
    $(element.currentTarget).closest(".paramGroup").find("i").toggleClass("icon-chevron-right").toggleClass("icon-chevron-down")
    category = $(element.currentTarget).data('category');
    children = $(".#{category}_children")
    if (children.is(':visible'))
      children.hide("blind", { direction: "vertical" }, 500)
    else
      children.show("blind", { direction: "vertical" }, 500)

  addDataCriteria: (criteria) =>
    @data_criteria[criteria.id] = criteria = new bonnie.DataCriteria(criteria.id, criteria)
    $c = $('#dataCriteria>div.paramGroup[data-category="' + criteria.buildCategory() + '"]');
    if $c.length
      $e = $c.find('span')
      $e.text(parseInt($e.text()) + 1)
    else
      $c = $('
        <div class="paramGroup" data-category="' + criteria.buildCategory() + '">
          <div class="paramItem">
            <div class="paramText ' + criteria.buildCategory() + '">
              <label>' + criteria.standard_category + '(<span>1</span>)</label>
            </div>
          </div>
        </div>
      ').insertBefore('#dataCriteria .paramGroup[data-category=newDataCriteria]')
    $('
      <div class="paramItem">
        <div class="paramText">
          <label>' + criteria.title + (if criteria.status then ': '+ criteria.status else '') + '</label>
        </div>
      </div>
    ').appendTo(
      $(
        $c.nextUntil('#dataCriteria .paramGroup', '#dataCriteria .paramChildren')[0] ||
        $('<div class="paramChildren ' + criteria.buildCategory() + '_children" style="background-color: #F5F5F5;"></div>').insertAfter($c)
      )
    )

class @bonnie.TemporalReference
  constructor: (temporal_reference) ->
    @offset = new bonnie.Value(temporal_reference.offset) if temporal_reference.offset
    @reference = temporal_reference.reference
    @type = temporal_reference.type
    @type_decoder = {'DURING':'During','SBS':'Starts Before Start of','SAS':'Starts After Start of','SBE':'Starts Before End of','SAE':'Starts After End of','EBS':'Ends Before Start of','EAS':'Ends After Start of'
                     ,'EBE':'Ends Before End of','EAE':'Ends After End of','SDU':'Starts During','EDU':'Ends During','ECW':'Ends Concurrent with','SCW':'Starts Concurrent with','CONCURRENT':'Concurrent with'}
  offset_text: =>
    if(@offset)
      value = @offset.value
      unit =  @offset.unit_text()
      inclusive = @offset.inclusive_text()
      if value > 0
        ">#{inclusive} #{value} #{unit}"
      else if value < 0
        "<#{inclusive} #{Math.abs(value)} #{unit}"
      else ''
    else
      ''
  type_text: =>
    @type_decoder[@type]

class @bonnie.SubsetOperator
  constructor: (subset_operator) ->
    @range = new bonnie.Range(subset_operator.value) if subset_operator.value
    @type = subset_operator.type
  title: =>
    range = " #{@range.text()}" if @range
    "#{@type}#{range || ''} of"

class @bonnie.DataCriteria
  constructor: (id, criteria, measure_period) ->
    @id = id
    @oid = criteria.code_list_id
    @property = criteria.property
    @standard_category = criteria.standard_category
    @qds_data_type = criteria.qds_data_type
    @title = criteria.title
    @status = criteria.status
    @type = criteria.type
    @category = this.buildCategory()
    @children_criteria = criteria.children_criteria
    @derivation_operator = criteria.derivation_operator
    @temporal_references = []
    if criteria.temporal_references
      for temporal in criteria.temporal_references
        @temporal_references.push(new bonnie.TemporalReference(temporal))
    @subset_operators = []
    if criteria.subset_operators
      for subset in criteria.subset_operators
        @subset_operators.push(new bonnie.SubsetOperator(subset))

    @temporalText = this.temporalText(measure_period)

  asHtml: (template) =>
    bonnie.template(template,this)

  temporalText: (measure_period) =>
    text = ''
    for temporal_reference in @temporal_references
      if temporal_reference.reference == 'MeasurePeriod'
        text += ' and ' if text.length > 0
        text += "#{temporal_reference.offset_text()}#{temporal_reference.type_text()} #{measure_period.name}"
    text

  temporalReferenceItems: =>
    items = []
    if @temporal_references.length > 0
      for temporal_reference in @temporal_references
        if temporal_reference.reference && temporal_reference.reference != 'MeasurePeriod'
          items.push({'conjunction':temporal_reference.type, 'items': [{'id':temporal_reference.reference}], 'negation':null, 'temporal':true, 'title': "#{temporal_reference.offset_text()}#{temporal_reference.type_text()}"})
    if (items.length > 0)
      items
    else
      null

  childrenCriteriaItems: =>
    items = []
    if @children_criteria.length > 0
      conjunction = 'or'
      conjunction = 'and' if @derivation_operator == 'XPRODUCT'
      for child in @children_criteria
        items.push({'conjunction':conjunction, 'items': [{'id':child}], 'negation':null})
    if (items.length > 0)
      items
    else
      null


  # get the category for the data criteria... check standard_category then qds_data_type
  # this probably needs to be done in a better way... probably direct f
  buildCategory: =>
    category = @standard_category
    # QDS data type is most specific, so use it if available. Otherwise use the standard category.
    category = @qds_data_type if @qds_data_type
    category = "patient characteristic" if category == 'individual_characteristic'
    category = category.replace('_',' ') if category
    category

class @bonnie.MeasurePeriod
  constructor: (measure_period) ->
    @name = "the measurement period"
    @type = measure_period['type']
    @high = new bonnie.Value(measure_period['high'])
    @low = new bonnie.Value(measure_period['low'])
    @width = new bonnie.Value(measure_period['width'])

class @bonnie.Range
  constructor: (range) ->
    @type = range['type']
    @high = new bonnie.Value(range['high']) if range['high']
    @low = new bonnie.Value(range['low']) if range['low']
    @width = new bonnie.Value(range['width']) if range['width']
  text: =>
    if (@high? && @low?)
      if (@high.value == @low.value and @high.inclusive and @low.inclusive)
        "=#{@low.value}"
      else
        ">#{@low.inclusive_text()} #{@low.value} and <#{@high.inclusive_text()} #{@high.value}}"
    else if (@high?)
      "<#{@high.inclusive_text()} #{@high.value}"
    else if (@low?)
      ">#{@low.inclusive_text()} #{@low.value}"
    else
      ''

class @bonnie.Value
  constructor: (value) ->
    @type = value['type']
    @unit = value['unit']
    @value = value['value']
    @inclusive = value['inclusive?']
    @unit_decoder = {'a':'year','mo':'month','wk':'week','d':'day','h':'hour','min':'minute','s':'second'}
  unit_text: =>
    if (@unit)
      unit = @unit_decoder[@unit]
      unit += "s " if @value != 1
    else
      ''
  inclusive_text: =>
    if (@inclusive? and @inclusive)
      '='
    else
      ''
  equals: (other) ->
    return @type == other.type && @value == other.value && @unit == other.unit && @inclusive == other.inclusive

@bonnie.template = (id, object={}) =>
  $("#bonnie_tmpl_#{id}").tmpl(object)

class Page
  constructor: (data_criteria, measure_period) ->
    bonnie.builder = new bonnie.Builder(data_criteria, measure_period)

  initialize: () =>
    $(document).on('click', '#dataCriteria .paramGroup', bonnie.builder.toggleDataCriteriaTree)
    $('.nav-tabs li').click((element) -> $('#workspace').empty() if !$(element.currentTarget).hasClass('active') )
    
    
$.widget 'ui.ContainerUI',
  options: {}
  _create: ->
    @container = @options.container
    @parent = @options.parent
    @builder = @options.builder
    console.log("builder= ",@builder)
    console.log("ui.ContainerUI this=",@)
    cc= @_createContainer()
    console.log("cc=", cc)
    @element.append(cc)
  _createContainer: ->
   
    $inner = $("<div>")
    #$inner = $dc.find(".paramItem")
    # $dc.css("width",300).css("height",100).find(".paramItem").css("width",280).css("height",80)
    for child in @container.children
      childItem = @_createItemUI(child)
      console.log("after create childItemUI, childItem=",childItem)
      $inner.append childItem
    return $inner.children()
      
  _createItemUI: (item) ->
    console.log("in createItemUI", item)

    if item.children
      $dc = @template('param_group')
      console.log($dc)
      console.log("@container instanceof queryStructure.AND ",@container instanceof queryStructure.AND)
      $dc.addClass(if @container instanceof queryStructure.AND then "and" else "or")
      $dc.find(".paramItem").droppable(
        over: @._over
        out: @._out
        drop: @._drop
      )
      $itemUI = $dc.find('.paramItem')
      console.log "item has children",item.children
      if item instanceof queryStructure.AND
        console.log("item is instanceof AND")
        # if we have no children array for this item, then we must be a leaf node (an individual data_criteria)
        # $itemUI = @template('param_group')
        $itemUI.AndContainerUI(
          parent: @
          container: item
          builder: @builder
        )
      if item instanceof queryStructure.OR
        console.log("item is instanceof OR")
        # if we have no children array for this item, then we must be a leaf node (an individual data_criteria)
        # $itemUI = @template('param_group')
        $itemUI.OrContainerUI(
          parent: @
          container: item
          builder: @builder
        )
      if !item instanceof queryStructure.AND && !item instanceof queryStructure.OR
        console.log("Error! - item is neither AND nor OR")
    else 
      console.log("item has no children", @)
      console.log("item.id=",item.id)
      console.log("@builder=",@builder)
      console.log("@builder.data_criteria=",@builder.data_criteria)
      $itemUI = @builder.data_criteria[item.id].asHtml("data_criteria_logic")
      # console.log("$itemUI = ", $itemUI)
      $itemUI.ItemUI(
        parent: @
        container: item
      )
      return $itemUI
    return $dc
  template: (id,object={}) ->
      $("#bonnie_tmpl_#{id}").tmpl(object)
  _over: ->
    $(@).parents('.paramItem').removeClass('droppable')
    $(@).addClass('droppable')

  _out: ->
    $(@).removeClass('droppable')
  _drop: ->
    $(@).removeClass('droppable')



  
$.widget 'ui.ItemUI',
  options: {}
  _init: ->
    console.log("inside ui.ItemUI _init")
    @parent = @parent = @options.parent
    @container = @options.container
    # @dataCriteria = @options.dataCriteria
    @element.append("<div>")
  _createItem: ->
    # bonnie.template("data_criteria_logic",@dataCriteria)
    # @element.append("<p>#{container.id}</p>")

$.widget "ui.AndContainerUI", $.ui.ContainerUI,
  options: {}
  collectionType: ->
    "AND"

$.widget "ui.OrContainerUI", $.ui.ContainerUI,
  options: {}
  collectionType: ->
    "OR"
