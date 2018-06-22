/**
 * Adds an alert to the top of the page.
 */
function addAlert(message, type) {
    type = type || 'alert-error';
    $('#content').prepend(
        '<div class="alert fade in" id="alert">' +
        '<button class="close" data-dismiss="alert">&times;</button>' +
        message + '</div>');
    $('#alert').addClass(type);
}

function getUrlParameter(name) {
    name = name.replace(/[\[]/, '\\[').replace(/[\]]/, '\\]');
    var regex = new RegExp('[\\?&]' + name + '=([^&#]*)');
    var results = regex.exec(location.search);
    return results === null ? '' : decodeURIComponent(results[1].replace(/\+/g, ' '));
}

const defaultSort = 'name';

function sortParam(name) {
    if (name === defaultSort) {
        return '';
    }
    return 'sort=' + name;
}

function reverseOrderParam(name) {
    const currentSort = getUrlParameter('sort');
    const currentOrder = getUrlParameter('order');
    const alreadySorted = currentSort === name || (currentSort === '' && name === 'name');
    return alreadySorted && currentOrder === '' ? 'order=desc' : '';
}

function getQueryParams() {
    // Create params from a list like 'sort=hits', 'order=desc' -> '?sort=hits&order=desc'
    var queryParams = '';
    var first = true;
    for (var i = 0; i < arguments.length; i++) {
        const param = arguments[i];
        if (param === '') {
            continue;
        }
        if (first) {
            queryParams += '?' + param;
            first = false;
        } else {
            queryParams += '&' + param;
        }
    }
    return queryParams;
}

function clearSearchResults() {
    $('#search-results').find('tr').not('thead tr').remove();
}

function hideSearchResults() {
    clearSearchResults();
    $('#search-results').hide();
}

function setSearchResults(results) {
    clearSearchResults();
    const $searchResults = $('#search-results');
    if (results !== null) {
        for (var i = 0; i < results.length; i++) {
            const result = results[i];
            if (result.secondary_url === null) {
                result.secondary_url = '';
            }
            const newRow = '<tr>' +
                '<td class="hide-overflow">go/' + result.name + '</td>' +
                '<td class="hide-overflow">' + result.owner + '</td>' +
                '<td class="hide-overflow">' + result.url + '</td>' +
                '<td class="hide-overflow">' + result.secondary_url + '</td>' +
                '<td class="hide-overflow">' + result.hits + '</td>' +
                '<td><a href="_edit?name=' + result.name + '"><i class="icon-pencil"></i></a></td>' +
                '</tr>';
            $searchResults.find('tbody').append(newRow);
        }
        $searchResults.find('table').show();
    } else {
        $searchResults.find('table').hide();
    }
    $searchResults.show();
}

function doSearch(params) {
    $.ajax({
        url: '/_ajax/search?' + params
    }).done(function(data) {
        if ('error' in data) {
            console.error(data.error);
        } else {
            if (data.results.length === 0) {
                setSearchResults(null);
            } else {
                setSearchResults(data.results);
            }
        }
    })
}

function searchByNameInput(cascading) {
    const nameSoFar = $('#name').val();
    if (nameSoFar.length >= 1) {
        $('#search-results').find('#title').text('Similar Shortcuts by Name');
        doSearch('name=' + nameSoFar);
    } else {
        if (cascading === false) {
            hideSearchResults();
        } else {
            searchByUrlInput(false);
        }
    }
}

function searchByUrlInput(cascading) {
    const urlSoFar = $('#url').val();
    if (urlSoFar.length >= 1) {
        $('#search-results').find('#title').text('Similar Shortcuts by URL');
        doSearch('url=' + urlSoFar);
    } else {
        if (cascading === false) {
            hideSearchResults();
        } else {
            searchByNameInput(false);
        }
    }
}

$(function() {

    $('#name').focus();

    $('#create-button').click(function() {

        // Close any pending alerts.
        $(".alert").alert('close');

        var name = $('#name').val();
        var url = $('#url').val();
        if (!name) {
            addAlert('Missing shortcut');
            return false;
        }
        if (!url) {
            addAlert('Missing URL');
            return false;
        }
        if (!name.match(/^[-_a-zA-Z0-9]+$/)) {
            addAlert('Invalid characters in shortcut name');
            return false;
        }

        $('#shortcut-form').submit();

        return false;
    });

    $('.cancel-button').click(function() {
        window.location.href = '/';
        return false;
    });

    $('#my-shortcuts').on('click', '.sortColumn', function() {
        var value = $(this).data('val');
        window.location.href = '/' + getQueryParams(sortParam(value), reverseOrderParam(value))
    });

    $('#all-shortcuts').on('click', '.sortColumn', function() {
        var value = $(this).data('val');
        window.location.href = '/_list' + getQueryParams(sortParam(value), reverseOrderParam(value));
    });

    $('input#name').on('keyup', function() {
        searchByNameInput();
    });

    $('input#url').on('keyup', function() {
        searchByUrlInput();
    });
});
