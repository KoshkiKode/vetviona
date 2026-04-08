                final fullName = place.getFullName(widget.eventDate);
                final info = place.getHistoricalInfo(widget.eventDate, context.read<TreeProvider>().colonizationLevel, fullName);
                return ListTile(
                  title: Text(place.getFullName(widget.eventDate)),
                  subtitle: Text(info),
                  onTap: () => Navigator.pop(context, place),
                );
