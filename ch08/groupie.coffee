connection = null
room = null
nickname = null
NS_MUC = "http://jabber.org/protocol/muc"
XML_MUC = xmlns : NS_MUC
joined = null
participants = null

on_presence = (presence) ->
    from = $(presence).attr 'from'

    # make sure this presence is for the right room
    if room is Strophe.getBareJidFromJid from
        nick = Strophe.getResourceFromJid from

        if $(presence).attr('type') is 'error' and not joined
            # error joining room; reset app
            connection.disconnect()
        else if(
            not participants[nick] and $(presence).attr('type') isnt 'unavailable')
            # add to participant list
            participants[nick] = true
            $('#participant-list').append "<li>#{nick}</li>"

            if joined
                $(document).trigger 'user_joined', nick
        else if participants[nick] and $(presence).attr('type') is 'unavailable'
            # remove from participants list
            $('#participant-list li').each ->
                if nick is $(this).text
                    $(this).remove()
                    return false
            $(document).trigger 'user_left', nick

        if $(presence).attr('type') isnt 'error' and not joined
            # check for status 110 to see if it's our own presence
            if $(presence).find("status[code='110']").length > 0
                # check if server changed our nick
                if $(presence).find("status[code='210']").length > 0
                    nickname = Strophe.getResourceFromJid(from)

                # room join complete
                $(document).trigger "room_joined"
    true

on_public_message = (message) ->
    from = $(message).attr 'from'
    nick = Strophe.getResourceFromJid from

    # make sure message is from the right place
    if room is Strophe.getBareJidFromJid from
        # is message from a user or the room itself?
        notice = not nick

        # messages from ouself will be styled differently
        nick_class = "nick"
        if nick is nickname
            nick_class += " self"

        body = $(message).children('body').text()

        delayed = $(message).children("delay").length > 0 or
            $(message).children("x[xmlns='jabber:x:delay']").length > 0

        if not notice
            delay_css = if delayed then " delayed" else ""
            add_message "<div class='message' #{delay_css}>&lt;" +
                        "<span class='#{nick_class}'>#{nick}</span>&gt; " +
                        "<span class='body'>#{body}</span></div>"
        else
            add_message "<div class='notice'>*** #{body}</div>"
    true

add_message = (msg) ->
    # detect if we are scrolled all the way down
    chat = $('#chat').get(0)
    at_bottom = chat.scrollTop >= chat.scrollHeight - chat.clientHeight

    $('#chat').append msg

    # if we were at the bottom, keep us at the bottom
    chat.scrollTop =  chat.scrollHeight if at_bottom

jQuery ->
    $('#login_dialog').dialog(
        autoOpen: true
        draggable: false
        modal: true
        title: 'Join a Room'
        buttons:
            "Join": ->
                room = $('#room').val()
                nickname = $('#nickname').val();

                $(document).trigger('connect',
                    jid: $('#jid').val()
                    password: $('#password').val()
                )

                $('#password').val()
                $(this).dialog('close')
    )

    $('#leave').click ->
        connection.send $pres(
                to  : "#{room}/#{nickname}"
                type: "unavailable"
            )
        connection.disconnected()

    $('#input').keypress (ev) ->
        if ev.which is 13
            ev.preventDefault()

            body = $(this).val()

            connection.send(
                $msg(
                    to: room
                    type: "groupchat")
                .c('body').t(body)
            )

            $(this).val ''

    $(document).bind(
        'connect': (ev, data) ->
            connection = new Strophe.Connection('http://bosh.metajack.im:5280/xmpp-httpbind')
            connection.connect(
                data.jid
                data.password
                (status) ->
                    if status is Strophe.Status.CONNECTED
                        $(document).trigger 'connected'
                    else if satus is Strophe.Status.DISCONNECTED
                        $(document).trigger 'disconnected'
            )

        'connected': ->
            joined = false
            participants = {}

            connection.send $pres().c('priority').t('-1')

            connection.addHandler(
                on_presence
                null
                "presence"
            )

            connection.addHandler(
                on_public_message
                null
                "message"
                "groupchat"
            )

            pres = $pres(to: "#{room}/#{nickname}").c('x', XML_MUC)
            connection.send pres

        'disconnected': ->
            connection = null
            divs = ['#participant-list', '#room-name', '#room-topic', '#chat']
            $(div).empty() for div in divs
            $('#login_dialog').dialog 'open'

        'room_joined': ->
            joined = true

            $('#leave').removeAttr('disabled')
            $('#room-name').text room

            $('#chat').append "<div class='notice'>*** Room joined.</div>"

        'user_joined': (ev, nick) ->
            add_message "<div class='notice'>*** #{nick} joined.</div>"

        'user_left': (ev, nick) ->
            add_message "<div class='notice'>*** #{nick} left.</div>"
    )
