class GabClient
    connection: null

    @jid_to_id: (jid) ->
        Strophe.getBareJidFromJid(jid)
            .replace(/@/g, "-")
            .replace(/\./g, "-")

    @presence_value: (elem) ->
        if elem.hasClass 'online'
            return 2
        else if elem.hasClass 'away'
            return 1
        return 0

    on_roster: (iq) =>
        $(iq).find('item').each ->
            jid = $(@).attr 'jid'
            name = $(@).attr('name') || jid

            # transform jid into an id
            jid_id = GabClient.jid_to_id jid

            contact = $(
                "<li id='#{jid_id}'>" +
                "<div class='roster-contact offline'>" +
                "<div class='roster-name'>#{name}</div>" +
                "<div class='roster-jid'>#{jid}</div></div></li>")

            GabClient.insert_contact contact

        # set up presence handler and send initial presence
        @connection.addHandler @on_presence, null, "presence"
        @connection.send $pres()

    on_presence: (presence) =>
        ptype  = $(presence).attr 'type'
        from   = $(presence).attr 'from'
        jid_id = GabClient.jid_to_id from

        if ptype is 'subscribe'
            # populate pending_subscriber, the approve-jid span, and
            # open the dialog
            @pending_subscriber = from
            $('#approve-jid').text Strophe.getBareJidFromJid from
            $('#approve_dialog').dialog 'open'
        else if ptype isnt 'error'
            contact = $("#roster-area li##{jid_id} .roster-contact")
                .removeClass("online")
                .removeClass("away")
                .removeClass("offline")
            if ptype is 'unavailable'
                contact.addClass "offline"
            else
                show = $(presence).find("show").text()
                if show is "" || show is "chat"
                    contact.addClass "online"
                else
                    contact.addClass "away"

            li = contact.parent()
            li.remove()
            GabClient.insert_contact li

        # reset addressing for user since their presence changed
        jid_id = GabClient.jid_to_id from
        $("#chat-#{jid_id}").data 'jid', Strophe.getBareJidFromJid from

        true

    on_roster_changed: (iq) ->
        $(iq).find('item').each ->
            sub = $(@).attr('subscription')
            jid = $(@).attr('jid')
            name = $(@).attr('name') || jid
            jid_id = GabClient.jid_to_id jid

            if sub is 'remove'
                # contact is being removed
                $("##{jid_id}").remove()
            else
                # contact is being added or modified
                status = $("##{jid_id}").attr('class') || "roster-contact offline"
                contact_html =
                    "<li id=#{jid_id}'>" +
                    "<div class='#{status}'>" +
                    "<div class='roster-name'>#{name}</div>" +
                    "<div class='roster-jid'>#{jid}</div>" +
                    "</div></li>"
                if $("##{jid_id}").length > 0
                    $("##{jid_id}").replaceWith contact_html
                else
                    GabClient.insert_contact $(contact_html)
        true

    on_message: (message) =>
        full_jid = $(message).attr('from')
        jid      = Strophe.getBareJidFromJid full_jid
        jid_id   = GabClient.jid_to_id jid

        if $("#chat-#{jid_id}").length is 0
            $('#chat-area').tabs 'add', "#chat-#{jid_id}", jid
            $("#chat-#{jid_id}").append(
                "<div class='chat-messages'></div>" +
                "<input type='text' class='chat-input'>")

        $('#chat-' + jid_id).data('jid', full_jid)

        $('#chat-area').tabs 'select', "#chat-#{jid_id}"
        $("#chat-#{jid_id}input").focus()

        composing = $(message).find('composing')
        if composing.length > 0
            $("#chat-#{jid_id} .chat-messages").append(
                "<div class='chat-event'>" +
                Strophe.getNodeFromJid(jid) +
                " is typing...</div>")

            @scroll_chat jid_id

        body = $(message).find "html > body"

        if body.length is 0
            body = $(message).find 'body'
            if body.length > 0
                body = body.text()
            else
                body = null
        else
            body = body.contents()

            span = $("<span></span>")
            body.each ->
                if document.importNode
                    $(document.importNode(@, true)).appendTo span
                else
                    # IE workaround
                    span.append @xml

            body = span

        if body
            # remove notifications since user is now active
            $("#chat-#{jid_id} .chat-event").remove()

            # add the new message
            $("#chat-#{jid_id} .chat-messages").append(
                "<div class='chat-message'>" +
                "&lt;<span class='chat-name'>" +
                Strophe.getNodeFromJid(jid) +
                "</span>&gt;<span class='chat-text'>" +
                "</span></div>")

            $("#chat-#{jid_id} .chat-message:last .chat-text")
                .append(body)

            @scroll_chat jid_id

        true

    scroll_chat: (jid_id) ->
        div = $("#chat-#{jid_id} .chat-messages").get(0)
        div.scrollTop = div.scrollHeight


    @insert_contact: (elem) =>
        jid = elem.find('.roster-jid').text()
        pres = GabClient.presence_value elem.find '.roster-contact'

        contacts = $ '#roster-area li'

        if contacts.length > 0
            inserted = false
            contacts.each ->
                cmp_pres = GabClient.presence_value(
                    $(@).find '.roster-contact'
                )
                cmp_jid = $(@).find('.roster-jid').text()

                if pres > cmp_pres
                    $(@).before elem
                    inserted = true
                    return false
                else if pres is cmp_pres
                    if jid < cmp_jid
                        $(@).before elem
                        inserted = true
                        return false

            if not inserted
                $('#roster-area ul').append elem
        else
            $('#roster-area ul').append elem

Gab = new GabClient

jQuery ->
    $('#login_dialog').dialog(
        autoOpen: true
        draggable: false
        modal: true
        title: 'Connect to XMPP'
        buttons:
            "Connect": ->
                $(document).trigger(
                    'connect'
                    jid: $('#jid').val()
                    password: $('#password').val()
                )

                $('#password').val ''
                $(@).dialog 'close'
    )

    $('#contact_dialog').dialog(
        autoOpen: false
        draggable: false
        modal: true
        title: 'Add a Contact'
        buttons:
            "Add": ->
                $(document).trigger(
                    'contact_added'
                    jid: $('#contact-jid').val().toLowerCase()
                    name: $('#contact-name').val()
                )
                $('#contact-jid').val ''
                $('#contact-name').val ''

                $(@).dialog 'close'
    )

    $('#new-contact').click (ev) ->
        $('#contact_dialog').dialog 'open'

    $('#approve_dialog').dialog(
        autoOpen: false
        draggable: false
        modal: true
        title: 'Subscription Request'
        buttons:
            "Deny": ->
                Gab.connection.send($pres(
                    to: Gab.pending_subscriber
                    "type": "unsubscribed"))
                Gab.pending_subscriber = null

                $(@).dialog('close')

            "Approve": ->
                Gab.connection.send($pres(
                    to: Gab.pending_subscriber
                    "type": "subscribed"))

                Gab.connection.send($pres(
                    to: Gab.pending_subscriber
                    "type": "subscribe"))

                Gab.pending_subscriber = null

                $(@).dialog 'close'
    )

    $('#chat-area').tabs().find('.ui-tabs-nav').sortable(axis: 'x')

    $('.roster-contact').live 'click', ->
        jid    = $(@).find(".roster-jid").text()
        name   = $(@).find(".roster-name").text()
        jid_id = GabClient.jid_to_id(jid)

        if $("#chat-#{jid_id}").length is 0
            $('#chat-area').tabs 'add', "#chat-#{jid_id}", name
            $("#chat-#{jid_id}").append(
                "<div class='chat-messages'></div>" +
                "<input type='text' class='chat-input'>")
            $("#chat-#{jid_id}").data 'jid', jid

        $('#chat-area').tabs 'select', "#chat-#{jid_id}"

        $("#chat-#{jid_id} input").focus()

    $('.chat-input').live 'keypress', (ev) ->
        jid = $(@).parent().data 'jid'

        if ev.which is 13
            ev.preventDefault()

            body = $(@).val()

            message = $msg(
                to: jid
                "type": "chat")
                .c('body').t(body).up()
                .c('active'
                    xmlns: "http://jabber.org/protocol/chatstates")

            Gab.connection.send message

            $(@).parent().find('.chat-messages').append(
                "<div class='chat-message'>&lt;" +
                "<span class='chat-name me'>" +
                Strophe.getNodeFromJid(Gab.connection.jid) +
                "</span>&gt;" +
                "<span class='chat-text'>#{body}</span></div>")

            Gab.scroll_chat GabClient.jid_to_id jid

            $(@).val ''
            $(@).parent().data 'composing', false
        else
            composing = $(@).parent().data 'composing'
            if not composing
                notify = $msg(
                    to: jid
                    "type": "chat")
                    .c(
                        'composing'
                        xmlns: "http://jabber.org/protocol/chatstates")
                Gab.connection.send notify

                $(@).parent().data 'composing', true

    $('#disconnect').click ->
        Gab.connection.disconnect()

    $('#chat_dialog').dialog(
        autoOpen: false
        draggable: false
        modal: true
        title: 'Start a Chat'
        buttons:
            "Start": ->
                jid = $('#chat-jid').val().toLowerCase()
                jid_id = GabClient.jid_to_id jid

                $('#chat-area').tabs 'add', "#chat-#{jid_id}", jid
                $('#chat-' + jid_id).append(
                    "<div class='chat-messages'></div>" +
                    "<input type='text' class='chat-input'>")

                $("#chat-#{jid_id}").data 'jid', jid

                $('#chat-area').tabs 'select', "#chat-#{jid_id}"
                $("#chat-#{jid_id} input").focus()

                $('#chat-jid').val ''

                $(@).dialog 'close'
    )

    $('#new-chat').click ->
        $('#chat_dialog').dialog 'open'

$(document).bind 'connect', (ev, data) ->
    conn = new Strophe.Connection 'http://bosh.metajack.im:5280/xmpp-httpbind'
    conn.connect(
        data.jid
        data.password
        (status) ->
            if status is Strophe.Status.CONNECTED
                $(document).trigger 'connected'
            else if status is Strophe.Status.DISCONNECTED
                $(document).trigger 'disconnected'
    )
    Gab.connection = conn

$(document).bind 'connected', ->
    iq = $iq(type: 'get')
        .c('query', xmlns: 'jabber:iq:roster')
    Gab.connection.sendIQ iq, Gab.on_roster

    Gab.connection.addHandler(
        Gab.on_roster_changed
        "jabber:iq:roster"
        "iq"
        "set"
    )

    Gab.connection.addHandler(
        Gab.on_message
        null
        "message"
        "chat"
    )

$(document).bind 'disconnected', ->
    Gab.connection = null
    Gab.pending_subscriber = null

    $('#roster-area ul').empty()
    $('#chat-area ul').empty()
    $('#chat-area div').remove()

    $('#login_dialog').dialog 'open'

$(document).bind 'contact_added', (ev, data) ->
    iq = $iq(type: "set")
        .c("query", xmlns: "jabber:iq:roster")
        .c("item", data)
    Gab.connection.sendIQ iq

    subscribe = $pres(
        to: data.jid
        "type": "subscribe"
    )
    Gab.connection.send subscribe
